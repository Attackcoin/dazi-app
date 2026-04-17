/**
 * antiGhosting.test.js
 * 覆盖 H-4 + M-1 (submitCheckin 事务化 + GPS 强制) 和 H-5 (ghostCount increment)
 */

jest.mock('firebase-admin', () => require('./setup').adminMock);
jest.mock('firebase-admin/firestore', () => require('./setup').firestoreModuleMock);
jest.mock('firebase-functions', () => require('./setup').makeFunctionsMock());
// ai 和 notifications 被 antiGhosting 间接引用，stub 掉
jest.mock('../src/ai', () => ({
  _generateRecapCard: jest.fn().mockResolvedValue({ success: true }),
}));
jest.mock('../src/notifications', () => ({
  _sendNotification: jest.fn().mockResolvedValue(undefined),
}));

const { fakeDb, makeContext, expectHttpsError } = require('./setup');
const antiGhosting = require('../src/antiGhosting');

beforeEach(() => {
  fakeDb._clear();
});

function seedUser(uid, fields = {}) {
  fakeDb._seed(`users/${uid}`, {
    name: uid,
    gender: 'male',
    ghostCount: 0,
    totalMeetups: 0,
    badges: [],
    rating: 5.0,
    ...fields,
  });
}

function seedPost(postId, fields = {}) {
  fakeDb._seed(`posts/${postId}`, {
    userId: 'owner',
    title: 'Test',
    category: 'eat',
    status: 'confirmed',
    ...fields,
  });
}

function seedMatch(matchId, participants, fields = {}) {
  fakeDb._seed(`matches/${matchId}`, {
    postId: 'p1',
    participants,
    checkedIn: [],
    checkinWindowOpen: true,
    status: 'confirmed',
    ...fields,
  });
}

// ─────────────────────────────────────────────────────
// submitCheckin — H-4 + M-1
// ─────────────────────────────────────────────────────
describe('submitCheckin (H-4 H-5 M-1)', () => {
  test('单人签到（2 人 match，其中 1 人）：checkedIn 更新但 match 未完成', async () => {
    seedUser('u1');
    seedUser('u2');
    seedPost('p1', { location: {} }); // 无坐标 → 不强制 GPS
    seedMatch('m1', ['u1', 'u2']);

    const r = await antiGhosting.submitCheckin(
      { matchId: 'm1' },
      makeContext('u1')
    );
    expect(r.allCheckedIn).toBe(false);
    expect(fakeDb._get('matches/m1').checkedIn).toEqual(['u1']);
    expect(fakeDb._get('matches/m1').status).toBe('confirmed');
    expect(fakeDb._get('users/u1').totalMeetups).toBe(0);
  });

  test('最后一人签到：match→completed, post→done, totalMeetups++', async () => {
    seedUser('u1', { totalMeetups: 3 });
    seedUser('u2', { totalMeetups: 5 });
    seedPost('p1', { location: {}, status: 'full' });
    seedMatch('m1', ['u1', 'u2'], { checkedIn: ['u1'] });

    const r = await antiGhosting.submitCheckin(
      { matchId: 'm1' },
      makeContext('u2')
    );
    expect(r.allCheckedIn).toBe(true);
    const match = fakeDb._get('matches/m1');
    expect(match.status).toBe('completed');
    expect(match.checkedIn.sort()).toEqual(['u1', 'u2']);
    expect(fakeDb._get('posts/p1').status).toBe('done');
    expect(fakeDb._get('users/u1').totalMeetups).toBe(4);
    expect(fakeDb._get('users/u2').totalMeetups).toBe(6);
  });

  test('已签到同一人二次：already-exists', async () => {
    seedUser('u1');
    seedUser('u2');
    seedPost('p1', { location: {} });
    seedMatch('m1', ['u1', 'u2'], { checkedIn: ['u1'] });

    await expectHttpsError(
      antiGhosting.submitCheckin({ matchId: 'm1' }, makeContext('u1')),
      'already-exists'
    );
  });

  test('非参与者：permission-denied', async () => {
    seedUser('u1');
    seedUser('u2');
    seedUser('stranger');
    seedPost('p1', { location: {} });
    seedMatch('m1', ['u1', 'u2']);

    await expectHttpsError(
      antiGhosting.submitCheckin({ matchId: 'm1' }, makeContext('stranger')),
      'permission-denied'
    );
  });

  test('签到窗口未开：failed-precondition', async () => {
    seedUser('u1');
    seedUser('u2');
    seedPost('p1', { location: {} });
    seedMatch('m1', ['u1', 'u2'], { checkinWindowOpen: false });

    await expectHttpsError(
      antiGhosting.submitCheckin({ matchId: 'm1' }, makeContext('u1')),
      'failed-precondition'
    );
  });

  test('M-1: post 有 lat/lng 但客户端未传 → invalid-argument', async () => {
    seedUser('u1');
    seedUser('u2');
    seedPost('p1', { location: { lat: 31.2, lng: 121.4 } });
    seedMatch('m1', ['u1', 'u2']);

    await expectHttpsError(
      antiGhosting.submitCheckin({ matchId: 'm1' }, makeContext('u1')),
      'invalid-argument'
    );
  });

  test('M-1: GPS 距离过远 → out-of-range', async () => {
    seedUser('u1');
    seedUser('u2');
    seedPost('p1', { location: { lat: 31.2, lng: 121.4 } });
    seedMatch('m1', ['u1', 'u2']);

    await expectHttpsError(
      antiGhosting.submitCheckin(
        { matchId: 'm1', lat: 39.9, lng: 116.4 }, // 北京
        makeContext('u1')
      ),
      'out-of-range'
    );
  });

  test('M-1: GPS 在范围内 → 签到成功', async () => {
    seedUser('u1');
    seedUser('u2');
    seedPost('p1', { location: { lat: 31.2, lng: 121.4 } });
    seedMatch('m1', ['u1', 'u2']);

    const r = await antiGhosting.submitCheckin(
      { matchId: 'm1', lat: 31.2001, lng: 121.4001 },
      makeContext('u1')
    );
    expect(r.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────
// submitQuickFeedback — T5-03 快速反馈
// ─────────────────────────────────────────────────────
describe('submitQuickFeedback (T5-03)', () => {
  test('参与者提交 "met" 反馈：成功写入 quickFeedback.{uid}', async () => {
    seedUser('u1');
    seedUser('u2');
    seedPost('p1');
    seedMatch('m1', ['u1', 'u2'], { status: 'completed', quickFeedback: {} });

    const r = await antiGhosting.submitQuickFeedback(
      { matchId: 'm1', feedback: 'met' },
      makeContext('u1')
    );
    expect(r.success).toBe(true);
    const match = fakeDb._get('matches/m1');
    expect(match.quickFeedback.u1).toBe('met');
  });

  test('参与者提交 "no_show" 反馈：成功写入', async () => {
    seedUser('u1');
    seedUser('u2');
    seedPost('p1');
    seedMatch('m1', ['u1', 'u2'], { status: 'ghosted', quickFeedback: {} });

    const r = await antiGhosting.submitQuickFeedback(
      { matchId: 'm1', feedback: 'no_show' },
      makeContext('u1')
    );
    expect(r.success).toBe(true);
    const match = fakeDb._get('matches/m1');
    expect(match.quickFeedback.u1).toBe('no_show');
  });

  test('双方都可提交，互不覆盖', async () => {
    seedUser('u1');
    seedUser('u2');
    seedPost('p1');
    seedMatch('m1', ['u1', 'u2'], { status: 'completed', quickFeedback: {} });

    await antiGhosting.submitQuickFeedback(
      { matchId: 'm1', feedback: 'met' },
      makeContext('u1')
    );
    await antiGhosting.submitQuickFeedback(
      { matchId: 'm1', feedback: 'no_show' },
      makeContext('u2')
    );

    const match = fakeDb._get('matches/m1');
    expect(match.quickFeedback.u1).toBe('met');
    expect(match.quickFeedback.u2).toBe('no_show');
  });

  test('重复提交：already-exists', async () => {
    seedUser('u1');
    seedUser('u2');
    seedPost('p1');
    seedMatch('m1', ['u1', 'u2'], {
      status: 'completed',
      quickFeedback: { u1: 'met' },
    });

    await expectHttpsError(
      antiGhosting.submitQuickFeedback(
        { matchId: 'm1', feedback: 'no_show' },
        makeContext('u1')
      ),
      'already-exists'
    );
  });

  test('非参与者：permission-denied', async () => {
    seedUser('u1');
    seedUser('u2');
    seedUser('stranger');
    seedPost('p1');
    seedMatch('m1', ['u1', 'u2'], { status: 'completed', quickFeedback: {} });

    await expectHttpsError(
      antiGhosting.submitQuickFeedback(
        { matchId: 'm1', feedback: 'met' },
        makeContext('stranger')
      ),
      'permission-denied'
    );
  });

  test('未结束的 match：failed-precondition', async () => {
    seedUser('u1');
    seedUser('u2');
    seedPost('p1');
    seedMatch('m1', ['u1', 'u2'], { status: 'confirmed', quickFeedback: {} });

    await expectHttpsError(
      antiGhosting.submitQuickFeedback(
        { matchId: 'm1', feedback: 'met' },
        makeContext('u1')
      ),
      'failed-precondition'
    );
  });

  test('无效 feedback 值：invalid-argument', async () => {
    seedUser('u1');
    seedUser('u2');
    seedPost('p1');
    seedMatch('m1', ['u1', 'u2'], { status: 'completed', quickFeedback: {} });

    await expectHttpsError(
      antiGhosting.submitQuickFeedback(
        { matchId: 'm1', feedback: 'maybe' },
        makeContext('u1')
      ),
      'invalid-argument'
    );
  });

  test('未登录：unauthenticated', async () => {
    await expectHttpsError(
      antiGhosting.submitQuickFeedback(
        { matchId: 'm1', feedback: 'met' },
        makeContext(null)
      ),
      'unauthenticated'
    );
  });

  test('match 不存在：not-found', async () => {
    await expectHttpsError(
      antiGhosting.submitQuickFeedback(
        { matchId: 'nonexistent', feedback: 'met' },
        makeContext('u1')
      ),
      'not-found'
    );
  });

  test('ghosted_all 状态也允许提交', async () => {
    seedUser('u1');
    seedUser('u2');
    seedPost('p1');
    seedMatch('m1', ['u1', 'u2'], { status: 'ghosted_all', quickFeedback: {} });

    const r = await antiGhosting.submitQuickFeedback(
      { matchId: 'm1', feedback: 'no_show' },
      makeContext('u1')
    );
    expect(r.success).toBe(true);
  });
});
