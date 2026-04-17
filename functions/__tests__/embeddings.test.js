jest.mock('firebase-admin', () => require('./setup').adminMock);
jest.mock('firebase-admin/firestore', () => require('./setup').firestoreModuleMock);
jest.mock('firebase-functions', () => require('./setup').makeFunctionsMock());
jest.mock('axios');

const axios = require('axios');
const { fakeDb, makeContext, expectHttpsError } = require('./setup');

process.env.OPENAI_API_KEY = 'test-key';

const {
  onPostCreatedEmbedding,
  onUserProfileUpdated,
  getRecommendedPosts,
  _generateEmbedding,
  _postToText,
  _userToText,
} = require('../src/embeddings');

const FAKE_EMBEDDING = Array.from({ length: 256 }, (_, i) => i / 256);

beforeEach(() => {
  fakeDb._clear();
  jest.clearAllMocks();
});

// ─── _postToText / _userToText ─────────────────────

describe('text extraction', () => {
  it('extracts post text', () => {
    const text = _postToText({
      title: '周末打球',
      description: '一起来',
      category: '运动',
      tags: ['篮球', '户外'],
      location: { name: '公园' },
    });
    expect(text).toBe('周末打球 一起来 运动 篮球 户外 公园');
  });

  it('handles missing fields', () => {
    const text = _postToText({ title: '标题' });
    expect(text).toBe('标题');
  });

  it('extracts user text', () => {
    const text = _userToText({
      name: '张三',
      bio: '喜欢运动',
      tags: ['篮球'],
      city: '北京',
    });
    expect(text).toBe('张三 喜欢运动 篮球 北京');
  });
});

// ─── _generateEmbedding ────────────────────────────

describe('_generateEmbedding', () => {
  it('calls OpenAI and returns embedding', async () => {
    axios.post.mockResolvedValueOnce({
      data: { data: [{ embedding: FAKE_EMBEDDING }] },
    });

    const result = await _generateEmbedding('test text');
    expect(result).toEqual(FAKE_EMBEDDING);
    expect(axios.post).toHaveBeenCalledWith(
      'https://api.openai.com/v1/embeddings',
      expect.objectContaining({
        input: 'test text',
        model: 'text-embedding-3-small',
        dimensions: 256,
      }),
      expect.any(Object),
    );
  });

  it('returns null for empty text', async () => {
    const result = await _generateEmbedding('');
    expect(result).toBeNull();
    expect(axios.post).not.toHaveBeenCalled();
  });

  it('returns null for null', async () => {
    expect(await _generateEmbedding(null)).toBeNull();
  });
});

// ─── onPostCreatedEmbedding ────────────────────────

describe('onPostCreatedEmbedding', () => {
  function makeSnap(postId, data) {
    fakeDb._seed(`posts/${postId}`, data);
    return {
      id: postId,
      ref: fakeDb.collection('posts').doc(postId),
      data: () => ({ ...data }),
    };
  }

  it('generates and stores embedding on post creation', async () => {
    axios.post.mockResolvedValueOnce({
      data: { data: [{ embedding: FAKE_EMBEDDING }] },
    });

    const snap = makeSnap('p1', {
      title: '周末打球',
      description: '公园篮球',
      category: '运动',
      tags: [],
    });

    await onPostCreatedEmbedding(snap);

    const updated = fakeDb._get('posts/p1');
    expect(updated.embedding).toBeDefined();
  });

  it('handles API failure gracefully', async () => {
    axios.post.mockRejectedValueOnce(new Error('timeout'));

    const snap = makeSnap('p2', { title: '标题', description: '描述' });
    await onPostCreatedEmbedding(snap); // should not throw

    const updated = fakeDb._get('posts/p2');
    expect(updated.embedding).toBeUndefined();
  });
});

// ─── onUserProfileUpdated ──────────────────────────

describe('onUserProfileUpdated', () => {
  function makeChange(userId, before, after) {
    fakeDb._seed(`users/${userId}`, after);
    return {
      before: { data: () => ({ ...before }) },
      after: {
        id: userId,
        ref: fakeDb.collection('users').doc(userId),
        data: () => ({ ...after }),
      },
    };
  }

  it('regenerates embedding when bio changes', async () => {
    axios.post.mockResolvedValueOnce({
      data: { data: [{ embedding: FAKE_EMBEDDING }] },
    });

    const change = makeChange('u1',
      { name: '张三', bio: '旧bio', tags: ['a'] },
      { name: '张三', bio: '新bio', tags: ['a'] },
    );

    await onUserProfileUpdated(change);

    const updated = fakeDb._get('users/u1');
    expect(updated.embedding).toBeDefined();
  });

  it('regenerates embedding when tags change', async () => {
    axios.post.mockResolvedValueOnce({
      data: { data: [{ embedding: FAKE_EMBEDDING }] },
    });

    const change = makeChange('u2',
      { name: '张三', bio: 'bio', tags: ['a'] },
      { name: '张三', bio: 'bio', tags: ['a', 'b'] },
    );

    await onUserProfileUpdated(change);
    expect(axios.post).toHaveBeenCalled();
  });

  it('skips when no relevant fields changed', async () => {
    const change = makeChange('u3',
      { name: '张三', bio: 'bio', tags: ['a'], city: '北京' },
      { name: '张三', bio: 'bio', tags: ['a'], city: '上海' },
    );

    await onUserProfileUpdated(change);
    expect(axios.post).not.toHaveBeenCalled();
  });

  it('skips when embeddingGeneratedAt changed (prevent loop)', async () => {
    const change = makeChange('u4',
      { name: '张三', bio: 'bio', tags: ['a'], embeddingGeneratedAt: 'old' },
      { name: '张三', bio: '新bio', tags: ['a'], embeddingGeneratedAt: 'new' },
    );

    await onUserProfileUpdated(change);
    expect(axios.post).not.toHaveBeenCalled();
  });
});

// ─── getRecommendedPosts ───────────────────────────

describe('getRecommendedPosts', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      getRecommendedPosts({}, makeContext(null)),
      'unauthenticated',
    );
  });

  it('requires existing user', async () => {
    await expectHttpsError(
      getRecommendedPosts({}, makeContext('nonexistent')),
      'not-found',
    );
  });

  it('returns empty when user has no text for embedding', async () => {
    fakeDb._seed('users/u1', { name: '', bio: '', tags: [] });

    // _generateEmbedding returns null for empty text
    const result = await getRecommendedPosts({}, makeContext('u1'));
    expect(result.posts).toEqual([]);
  });
});
