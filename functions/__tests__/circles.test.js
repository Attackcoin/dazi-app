jest.mock('firebase-admin', () => require('./setup').adminMock);
jest.mock('firebase-admin/firestore', () => require('./setup').firestoreModuleMock);
jest.mock('firebase-functions', () => require('./setup').makeFunctionsMock());

const { fakeDb, makeContext, expectHttpsError } = require('./setup');

const {
  createCircle,
  joinCircle,
  leaveCircle,
  postMoment,
} = require('../src/circles');

beforeEach(() => {
  fakeDb._clear();
  jest.clearAllMocks();
});

// ─── createCircle ─────────────────────────────────

describe('createCircle', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      createCircle({ name: '跑步圈' }, makeContext(null)),
      'unauthenticated',
    );
  });

  it('requires name', async () => {
    await expectHttpsError(
      createCircle({}, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('rejects empty name', async () => {
    await expectHttpsError(
      createCircle({ name: '   ' }, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('rejects name over 30 chars', async () => {
    await expectHttpsError(
      createCircle({ name: 'a'.repeat(31) }, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('rejects description over 500 chars', async () => {
    await expectHttpsError(
      createCircle({ name: '圈子', description: 'x'.repeat(501) }, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('creates circle with owner as first member', async () => {
    fakeDb._seed('users/u1', { name: '张三', avatar: 'av1.jpg' });

    const result = await createCircle(
      { name: '跑步圈', description: '一起跑', category: '运动', icon: '🏃' },
      makeContext('u1'),
    );

    expect(result.success).toBe(true);
    expect(result.circleId).toBeTruthy();

    // 验证圈子文档
    const circle = fakeDb._get(`circles/${result.circleId}`);
    expect(circle.name).toBe('跑步圈');
    expect(circle.description).toBe('一起跑');
    expect(circle.category).toBe('运动');
    expect(circle.icon).toBe('🏃');
    expect(circle.memberCount).toBe(1);
    expect(circle.postCount).toBe(0);
    expect(circle.createdBy).toBe('u1');
    expect(circle.creatorName).toBe('张三');

    // 验证成员文档
    const member = fakeDb._get(`circles/${result.circleId}/members/u1`);
    expect(member.role).toBe('owner');
    expect(member.name).toBe('张三');
    expect(member.avatar).toBe('av1.jpg');
  });

  it('works without user doc', async () => {
    const result = await createCircle(
      { name: '匿名圈' },
      makeContext('u_new'),
    );
    expect(result.success).toBe(true);
    const circle = fakeDb._get(`circles/${result.circleId}`);
    expect(circle.creatorName).toBe('');
  });
});

// ─── joinCircle ──────────────────────────────────

describe('joinCircle', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      joinCircle({ circleId: 'c1' }, makeContext(null)),
      'unauthenticated',
    );
  });

  it('requires circleId', async () => {
    await expectHttpsError(
      joinCircle({}, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('rejects non-existent circle', async () => {
    await expectHttpsError(
      joinCircle({ circleId: 'nonexistent' }, makeContext('u1')),
      'not-found',
    );
  });

  it('joins circle and increments memberCount', async () => {
    fakeDb._seed('circles/c1', { name: '跑步圈', memberCount: 1 });
    fakeDb._seed('users/u2', { name: '李四', avatar: 'av2.jpg' });

    const result = await joinCircle({ circleId: 'c1' }, makeContext('u2'));
    expect(result.success).toBe(true);

    // memberCount +1
    const circle = fakeDb._get('circles/c1');
    expect(circle.memberCount).toBe(2);

    // 成员文档
    const member = fakeDb._get('circles/c1/members/u2');
    expect(member.role).toBe('member');
    expect(member.name).toBe('李四');
  });

  it('is idempotent — already joined returns success', async () => {
    fakeDb._seed('circles/c1', { name: '跑步圈', memberCount: 2 });
    fakeDb._seed('circles/c1/members/u2', { role: 'member' });

    const result = await joinCircle({ circleId: 'c1' }, makeContext('u2'));
    expect(result.success).toBe(true);
    expect(result.alreadyMember).toBe(true);

    // memberCount unchanged
    const circle = fakeDb._get('circles/c1');
    expect(circle.memberCount).toBe(2);
  });
});

// ─── leaveCircle ─────────────────────────────────

describe('leaveCircle', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      leaveCircle({ circleId: 'c1' }, makeContext(null)),
      'unauthenticated',
    );
  });

  it('requires circleId', async () => {
    await expectHttpsError(
      leaveCircle({}, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('returns success if not a member', async () => {
    const result = await leaveCircle({ circleId: 'c1' }, makeContext('u1'));
    expect(result.success).toBe(true);
    expect(result.notMember).toBe(true);
  });

  it('owner cannot leave', async () => {
    fakeDb._seed('circles/c1/members/u1', { role: 'owner' });

    await expectHttpsError(
      leaveCircle({ circleId: 'c1' }, makeContext('u1')),
      'failed-precondition',
    );
  });

  it('member leaves and memberCount decremented', async () => {
    fakeDb._seed('circles/c1', { name: '跑步圈', memberCount: 3 });
    fakeDb._seed('circles/c1/members/u2', { role: 'member' });

    const result = await leaveCircle({ circleId: 'c1' }, makeContext('u2'));
    expect(result.success).toBe(true);

    // memberCount -1
    const circle = fakeDb._get('circles/c1');
    expect(circle.memberCount).toBe(2);

    // 成员文档已删
    expect(fakeDb._get('circles/c1/members/u2')).toBeUndefined();
  });
});

// ─── postMoment ──────────────────────────────────

describe('postMoment', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      postMoment({ circleId: 'c1', text: '你好' }, makeContext(null)),
      'unauthenticated',
    );
  });

  it('requires circleId', async () => {
    await expectHttpsError(
      postMoment({ text: '你好' }, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('requires text', async () => {
    await expectHttpsError(
      postMoment({ circleId: 'c1' }, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('rejects empty text', async () => {
    await expectHttpsError(
      postMoment({ circleId: 'c1', text: '   ' }, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('rejects text over 1000 chars', async () => {
    fakeDb._seed('circles/c1/members/u1', { role: 'member' });
    await expectHttpsError(
      postMoment({ circleId: 'c1', text: 'x'.repeat(1001) }, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('rejects non-member', async () => {
    await expectHttpsError(
      postMoment({ circleId: 'c1', text: '你好' }, makeContext('u1')),
      'permission-denied',
    );
  });

  it('creates moment and increments postCount', async () => {
    fakeDb._seed('circles/c1', { name: '跑步圈', postCount: 0 });
    fakeDb._seed('circles/c1/members/u1', { role: 'member' });
    fakeDb._seed('users/u1', { name: '张三', avatar: 'av1.jpg' });

    const result = await postMoment(
      { circleId: 'c1', text: '今天跑了5公里', images: ['img1.jpg', 'img2.jpg'] },
      makeContext('u1'),
    );

    expect(result.success).toBe(true);
    expect(result.momentId).toBeTruthy();

    // postCount +1
    const circle = fakeDb._get('circles/c1');
    expect(circle.postCount).toBe(1);

    // 验证动态文档
    const moment = fakeDb._get(`circles/c1/moments/${result.momentId}`);
    expect(moment.uid).toBe('u1');
    expect(moment.authorName).toBe('张三');
    expect(moment.text).toBe('今天跑了5公里');
    expect(moment.images).toEqual(['img1.jpg', 'img2.jpg']);
    expect(moment.likeCount).toBe(0);
  });

  it('caps images at 9', async () => {
    fakeDb._seed('circles/c1', { name: '圈子', postCount: 0 });
    fakeDb._seed('circles/c1/members/u1', { role: 'member' });
    fakeDb._seed('users/u1', { name: '张三' });

    const manyImages = Array.from({ length: 15 }, (_, i) => `img${i}.jpg`);
    const result = await postMoment(
      { circleId: 'c1', text: '测试', images: manyImages },
      makeContext('u1'),
    );

    const moment = fakeDb._get(`circles/c1/moments/${result.momentId}`);
    expect(moment.images.length).toBe(9);
  });
});
