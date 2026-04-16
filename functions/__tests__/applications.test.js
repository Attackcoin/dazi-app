/**
 * applications.test.js
 * 覆盖 H-1 / H-2 / H-3 / H-5 / M-9
 */

jest.mock('firebase-admin', () => require('./setup').adminMock);
jest.mock('firebase-admin/firestore', () => require('./setup').firestoreModuleMock);
jest.mock('firebase-functions', () =>
  require('./setup').makeFunctionsMock()
);

const { fakeDb, makeContext, expectHttpsError } = require('./setup');

// require 源码 — admin/functions 此时已被 mock
const applications = require('../src/applications');

beforeEach(() => {
  fakeDb._clear();
});

// 种子辅助
function seedUser(uid, fields = {}) {
  fakeDb._seed(`users/${uid}`, {
    name: `User ${uid}`,
    gender: 'male',
    isRestricted: false,
    ghostCount: 0,
    rating: 5.0,
    ratingSum: 0,
    ratingCount: 0,
    totalMeetups: 0,
    badges: [],
    ...fields,
  });
}

function seedPost(postId, ownerUid, fields = {}) {
  fakeDb._seed(`posts/${postId}`, {
    userId: ownerUid,
    title: 'Test Post',
    category: 'eat>dinner',
    status: 'open',
    totalSlots: 3,
    acceptedGender: { male: 0, female: 0 },
    waitlist: [],
    depositAmount: 0,
    ...fields,
  });
}

function seedMatch(matchId, participants, fields = {}) {
  fakeDb._seed(`matches/${matchId}`, {
    postId: 'p1',
    participants,
    checkedIn: [],
    checkinWindowOpen: false,
    status: 'confirmed',
    ...fields,
  });
}

// ─────────────────────────────────────────────────────
// H-1: applyToPost 确定性 docId + 幂等
// ─────────────────────────────────────────────────────
describe('applyToPost (H-1 确定性 docId)', () => {
  test('首次申请：创建 applications/{postId}_{uid}', async () => {
    seedUser('applicant1', { gender: 'female' });
    seedUser('owner1');
    seedPost('post1', 'owner1');

    const result = await applications.applyToPost(
      { postId: 'post1' },
      makeContext('applicant1')
    );

    expect(result.success).toBe(true);
    expect(result.applicationId).toBe('post1_applicant1');
    const appDoc = fakeDb._get('applications/post1_applicant1');
    expect(appDoc.status).toBe('pending');
    expect(appDoc.applicantId).toBe('applicant1');
  });

  test('第二次申请（状态 pending）：already-exists', async () => {
    seedUser('applicant1', { gender: 'female' });
    seedUser('owner1');
    seedPost('post1', 'owner1');
    fakeDb._seed('applications/post1_applicant1', {
      postId: 'post1',
      applicantId: 'applicant1',
      status: 'pending',
    });

    await expectHttpsError(
      applications.applyToPost({ postId: 'post1' }, makeContext('applicant1')),
      'already-exists'
    );
  });

  test('ghostCount >= 3：permission-denied（H-5 配套）', async () => {
    seedUser('ghoster', { ghostCount: 3, gender: 'male' });
    seedUser('owner1');
    seedPost('post1', 'owner1');

    await expectHttpsError(
      applications.applyToPost({ postId: 'post1' }, makeContext('ghoster')),
      'permission-denied'
    );
  });

  test('isRestricted=true：permission-denied', async () => {
    seedUser('banned', { isRestricted: true });
    seedUser('owner1');
    seedPost('post1', 'owner1');

    await expectHttpsError(
      applications.applyToPost({ postId: 'post1' }, makeContext('banned')),
      'permission-denied'
    );
  });

  test('帖子状态 full：failed-precondition', async () => {
    seedUser('applicant1');
    seedUser('owner1');
    seedPost('post1', 'owner1', { status: 'full' });

    await expectHttpsError(
      applications.applyToPost({ postId: 'post1' }, makeContext('applicant1')),
      'failed-precondition'
    );
  });

  test('申请自己发布的帖子：invalid-argument', async () => {
    seedUser('owner1');
    seedPost('post1', 'owner1');

    await expectHttpsError(
      applications.applyToPost({ postId: 'post1' }, makeContext('owner1')),
      'invalid-argument'
    );
  });

  test('未登录：unauthenticated', async () => {
    await expectHttpsError(
      applications.applyToPost({ postId: 'post1' }, makeContext(null)),
      'unauthenticated'
    );
  });
});

// ─────────────────────────────────────────────────────
// M-9: acceptApplication 满员清理 pending
// ─────────────────────────────────────────────────────
describe('acceptApplication (M-9 满员清理)', () => {
  test('接受最后 1 人时：其它 pending 被 auto_rejected', async () => {
    seedUser('owner1');
    seedUser('a1', { gender: 'male' });
    seedUser('a2', { gender: 'female' });
    seedUser('a3', { gender: 'male' });
    // totalSlots=2 → slots-1=1，接受第 1 人就触发满员
    seedPost('post1', 'owner1', { totalSlots: 2 });

    fakeDb._seed('applications/post1_a1', {
      postId: 'post1',
      applicantId: 'a1',
      status: 'pending',
    });
    fakeDb._seed('applications/post1_a2', {
      postId: 'post1',
      applicantId: 'a2',
      status: 'pending',
    });
    fakeDb._seed('applications/post1_a3', {
      postId: 'post1',
      applicantId: 'a3',
      status: 'pending',
    });

    await applications.acceptApplication(
      { applicationId: 'post1_a1' },
      makeContext('owner1')
    );

    expect(fakeDb._get('applications/post1_a1').status).toBe('accepted');
    expect(fakeDb._get('applications/post1_a2').status).toBe('auto_rejected');
    expect(fakeDb._get('applications/post1_a3').status).toBe('auto_rejected');
    expect(fakeDb._get('posts/post1').status).toBe('full');
  });

  test('非发布者调用：permission-denied', async () => {
    seedUser('owner1');
    seedUser('applicant1');
    seedPost('post1', 'owner1');
    fakeDb._seed('applications/post1_applicant1', {
      postId: 'post1',
      applicantId: 'applicant1',
      status: 'pending',
    });

    await expectHttpsError(
      applications.acceptApplication(
        { applicationId: 'post1_applicant1' },
        makeContext('otheruser')
      ),
      'permission-denied'
    );
  });
});

// ─────────────────────────────────────────────────────
// H-2 + H-3: submitReview toUserId 校验 + 事务化
// ─────────────────────────────────────────────────────
describe('submitReview (H-2 H-3)', () => {
  beforeEach(() => {
    seedUser('u1');
    seedUser('u2');
    seedMatch('m1', ['u1', 'u2'], { status: 'completed' });
  });

  test('toUserId 不在 participants：permission-denied (H-2)', async () => {
    seedUser('stranger');
    await expectHttpsError(
      applications.submitReview(
        { matchId: 'm1', toUserId: 'stranger', rating: 5, comment: 'ok' },
        makeContext('u1')
      ),
      'permission-denied'
    );
  });

  test('toUserId == fromUid（自评）：permission-denied (H-2)', async () => {
    await expectHttpsError(
      applications.submitReview(
        { matchId: 'm1', toUserId: 'u1', rating: 5 },
        makeContext('u1')
      ),
      'permission-denied'
    );
  });

  test('正常评价：review 写入 + ratingSum/ratingCount 原子递增 (H-3)', async () => {
    await applications.submitReview(
      { matchId: 'm1', toUserId: 'u2', rating: 4 },
      makeContext('u1')
    );

    const review = fakeDb._get('reviews/m1_u1_u2');
    expect(review).toBeDefined();
    expect(review.rating).toBe(4);

    const u2 = fakeDb._get('users/u2');
    expect(u2.ratingSum).toBe(4);
    expect(u2.ratingCount).toBe(1);
  });

  test('重复评价：already-exists', async () => {
    fakeDb._seed('reviews/m1_u1_u2', {
      matchId: 'm1',
      fromUser: 'u1',
      toUser: 'u2',
      rating: 5,
    });
    await expectHttpsError(
      applications.submitReview(
        { matchId: 'm1', toUserId: 'u2', rating: 5 },
        makeContext('u1')
      ),
      'already-exists'
    );
  });

  test('match 未 completed：failed-precondition', async () => {
    fakeDb._seed('matches/m1', {
      participants: ['u1', 'u2'],
      status: 'confirmed',
    });
    await expectHttpsError(
      applications.submitReview(
        { matchId: 'm1', toUserId: 'u2', rating: 5 },
        makeContext('u1')
      ),
      'failed-precondition'
    );
  });

  test('rating 超出 1-5：invalid-argument', async () => {
    await expectHttpsError(
      applications.submitReview(
        { matchId: 'm1', toUserId: 'u2', rating: 6 },
        makeContext('u1')
      ),
      'invalid-argument'
    );
  });
});
