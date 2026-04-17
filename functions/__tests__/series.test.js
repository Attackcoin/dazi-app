/**
 * series.test.js
 * 覆盖：createSeriesPosts onCall
 * Mock 边界：firebase-admin（内存 Firestore）
 */

jest.mock('firebase-admin', () => require('./setup').adminMock);
jest.mock('firebase-admin/firestore', () => require('./setup').firestoreModuleMock);
jest.mock('firebase-functions', () => require('./setup').makeFunctionsMock());

const { fakeDb, makeContext, expectHttpsError } = require('./setup');
const series = require('../src/series');

beforeEach(() => {
  fakeDb._clear();
});

// 种子辅助
function seedUser(uid, fields = {}) {
  fakeDb._seed(`users/${uid}`, {
    name: `User ${uid}`,
    avatar: `https://example.com/${uid}.jpg`,
    ...fields,
  });
}

// 标准模板帖子
function makeTemplate(overrides = {}) {
  return {
    title: '周末跑步',
    description: '一起来跑步吧',
    category: '运动',
    time: '2026-05-01T09:00:00Z',
    location: { city: '北京', address: '奥林匹克公园' },
    totalSlots: 4,
    minSlots: 2,
    gender: 'any',
    genderQuota: null,
    costType: 'free',
    depositAmount: 0,
    images: [],
    tags: ['跑步', '运动'],
    isSocialAnxietyFriendly: false,
    isInstant: false,
    ...overrides,
  };
}

// ─────────────────────────────────────────────────────
// createSeriesPosts
// ─────────────────────────────────────────────────────
describe('createSeriesPosts', () => {
  test('未认证用户：unauthenticated', async () => {
    await expectHttpsError(
      series.createSeriesPosts(
        { templatePost: makeTemplate(), recurrence: 'weekly', totalWeeks: 4 },
        makeContext(null)
      ),
      'unauthenticated'
    );
  });

  test('totalWeeks < 2：invalid-argument', async () => {
    seedUser('u1');
    await expectHttpsError(
      series.createSeriesPosts(
        { templatePost: makeTemplate(), recurrence: 'weekly', totalWeeks: 1 },
        makeContext('u1')
      ),
      'invalid-argument'
    );
  });

  test('totalWeeks > 8：invalid-argument', async () => {
    seedUser('u1');
    await expectHttpsError(
      series.createSeriesPosts(
        { templatePost: makeTemplate(), recurrence: 'weekly', totalWeeks: 9 },
        makeContext('u1')
      ),
      'invalid-argument'
    );
  });

  test('totalWeeks 非整数：invalid-argument', async () => {
    seedUser('u1');
    await expectHttpsError(
      series.createSeriesPosts(
        { templatePost: makeTemplate(), recurrence: 'weekly', totalWeeks: 3.5 },
        makeContext('u1')
      ),
      'invalid-argument'
    );
  });

  test('recurrence 非法值：invalid-argument', async () => {
    seedUser('u1');
    await expectHttpsError(
      series.createSeriesPosts(
        { templatePost: makeTemplate(), recurrence: 'daily', totalWeeks: 4 },
        makeContext('u1')
      ),
      'invalid-argument'
    );
  });

  test('缺少 templatePost：invalid-argument', async () => {
    seedUser('u1');
    await expectHttpsError(
      series.createSeriesPosts(
        { recurrence: 'weekly', totalWeeks: 4 },
        makeContext('u1')
      ),
      'invalid-argument'
    );
  });

  test('用户不存在：not-found', async () => {
    // 不 seedUser
    await expectHttpsError(
      series.createSeriesPosts(
        { templatePost: makeTemplate(), recurrence: 'weekly', totalWeeks: 3 },
        makeContext('u1')
      ),
      'not-found'
    );
  });

  test('正常创建 weekly 系列（4 周）：生成 4 个文档，时间递增 7 天', async () => {
    seedUser('u1', { name: '跑步达人', avatar: 'https://img/u1.png' });

    const result = await series.createSeriesPosts(
      {
        templatePost: makeTemplate({ title: '周末跑步' }),
        recurrence: 'weekly',
        totalWeeks: 4,
      },
      makeContext('u1')
    );

    // 验证返回值
    expect(result.seriesId).toBeDefined();
    expect(result.postIds).toHaveLength(4);

    // 验证生成的文档
    const allPosts = fakeDb._all('posts');
    // 过滤出属于此系列的帖子（排除 seriesId 占位文档可能）
    const seriesPosts = allPosts.filter(
      (p) => p.data.seriesId === result.seriesId
    );
    expect(seriesPosts).toHaveLength(4);

    // 按 seriesWeek 排序
    seriesPosts.sort((a, b) => a.data.seriesWeek - b.data.seriesWeek);

    const baseTime = new Date('2026-05-01T09:00:00Z').getTime();

    for (let i = 0; i < 4; i++) {
      const post = seriesPosts[i].data;
      expect(post.seriesWeek).toBe(i + 1);
      expect(post.seriesTotalWeeks).toBe(4);
      expect(post.recurrence).toBe('weekly');
      expect(post.userId).toBe('u1');
      expect(post.status).toBe('open');
      expect(post.waitlist).toEqual([]);
      expect(post.acceptedGender).toEqual({ male: 0, female: 0 });
      expect(post.publisherName).toBe('跑步达人');
      expect(post.publisherAvatar).toBe('https://img/u1.png');
      expect(post.title).toBe(`周末跑步（第${i + 1}/4周）`);

      // 验证时间递增 7 天
      const expectedTime = baseTime + i * 7 * 24 * 60 * 60 * 1000;
      expect(post.time.toDate().getTime()).toBe(expectedTime);
    }
  });

  test('正常创建 biweekly 系列（3 周）：时间递增 14 天', async () => {
    seedUser('u2', { name: '读书人', avatar: 'https://img/u2.png' });

    const result = await series.createSeriesPosts(
      {
        templatePost: makeTemplate({
          title: '读书会',
          time: '2026-06-01T14:00:00Z',
          category: '文化',
        }),
        recurrence: 'biweekly',
        totalWeeks: 3,
      },
      makeContext('u2')
    );

    expect(result.seriesId).toBeDefined();
    expect(result.postIds).toHaveLength(3);

    const allPosts = fakeDb._all('posts');
    const seriesPosts = allPosts.filter(
      (p) => p.data.seriesId === result.seriesId
    );
    expect(seriesPosts).toHaveLength(3);

    seriesPosts.sort((a, b) => a.data.seriesWeek - b.data.seriesWeek);

    const baseTime = new Date('2026-06-01T14:00:00Z').getTime();

    for (let i = 0; i < 3; i++) {
      const post = seriesPosts[i].data;
      expect(post.seriesWeek).toBe(i + 1);
      expect(post.seriesTotalWeeks).toBe(3);
      expect(post.recurrence).toBe('biweekly');
      expect(post.category).toBe('文化');
      expect(post.title).toBe(`读书会（第${i + 1}/3周）`);

      // 验证时间递增 14 天
      const expectedTime = baseTime + i * 14 * 24 * 60 * 60 * 1000;
      expect(post.time.toDate().getTime()).toBe(expectedTime);
    }
  });

  test('每个文档的 seriesId 相同', async () => {
    seedUser('u1');

    const result = await series.createSeriesPosts(
      {
        templatePost: makeTemplate(),
        recurrence: 'weekly',
        totalWeeks: 2,
      },
      makeContext('u1')
    );

    const allPosts = fakeDb._all('posts');
    const seriesPosts = allPosts.filter(
      (p) => p.data.seriesId === result.seriesId
    );

    // 所有帖子共享同一个 seriesId
    const seriesIds = new Set(seriesPosts.map((p) => p.data.seriesId));
    expect(seriesIds.size).toBe(1);
    expect(seriesPosts).toHaveLength(2);
  });

  test('模板字段正确复制到每个文档', async () => {
    seedUser('u1');

    const template = makeTemplate({
      description: '详细描述',
      totalSlots: 6,
      minSlots: 3,
      gender: 'female',
      costType: 'aa',
      depositAmount: 50,
      images: ['img1.jpg', 'img2.jpg'],
      tags: ['标签1', '标签2'],
      isSocialAnxietyFriendly: true,
      isInstant: true,
    });

    const result = await series.createSeriesPosts(
      { templatePost: template, recurrence: 'weekly', totalWeeks: 2 },
      makeContext('u1')
    );

    const allPosts = fakeDb._all('posts');
    const seriesPosts = allPosts.filter(
      (p) => p.data.seriesId === result.seriesId
    );

    for (const { data } of seriesPosts) {
      expect(data.description).toBe('详细描述');
      expect(data.totalSlots).toBe(6);
      expect(data.minSlots).toBe(3);
      expect(data.gender).toBe('female');
      expect(data.costType).toBe('aa');
      expect(data.depositAmount).toBe(50);
      expect(data.images).toEqual(['img1.jpg', 'img2.jpg']);
      expect(data.tags).toEqual(['标签1', '标签2']);
      expect(data.isSocialAnxietyFriendly).toBe(true);
      expect(data.isInstant).toBe(true);
    }
  });
});
