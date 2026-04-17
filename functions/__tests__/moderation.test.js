jest.mock('firebase-admin', () => require('./setup').adminMock);
jest.mock('firebase-admin/firestore', () => require('./setup').firestoreModuleMock);
jest.mock('firebase-functions', () => require('./setup').makeFunctionsMock());
jest.mock('axios');

const axios = require('axios');
const { fakeDb } = require('./setup');

// Set env var before requiring module
process.env.OPENAI_API_KEY = 'test-key';

const {
  onPostCreatedModeration,
  onPostUpdatedModeration,
  _moderateText,
  _moderateImage,
} = require('../src/moderation');

beforeEach(() => {
  fakeDb._clear();
  jest.clearAllMocks();
});

// ─── _moderateText ─────────────────────────────────

describe('_moderateText', () => {
  it('returns not flagged for clean text', async () => {
    axios.post.mockResolvedValueOnce({
      data: {
        results: [{
          flagged: false,
          categories: { sexual: false, violence: false, hate: false },
        }],
      },
    });

    const result = await _moderateText('Hello world');
    expect(result.flagged).toBe(false);
    expect(result.categories).toEqual([]);
    expect(axios.post).toHaveBeenCalledWith(
      'https://api.openai.com/v1/moderations',
      { input: 'Hello world', model: 'omni-moderation-latest' },
      expect.objectContaining({ headers: { Authorization: 'Bearer test-key' } }),
    );
  });

  it('returns flagged categories for harmful text', async () => {
    axios.post.mockResolvedValueOnce({
      data: {
        results: [{
          flagged: true,
          categories: { sexual: false, violence: true, hate: true, harassment: false },
        }],
      },
    });

    const result = await _moderateText('violent content');
    expect(result.flagged).toBe(true);
    expect(result.categories).toEqual(['violence', 'hate']);
  });

  it('returns not flagged for empty text', async () => {
    const result = await _moderateText('');
    expect(result.flagged).toBe(false);
    expect(axios.post).not.toHaveBeenCalled();
  });

  it('returns not flagged for null text', async () => {
    const result = await _moderateText(null);
    expect(result.flagged).toBe(false);
  });
});

// ─── _moderateImage ────────────────────────────────

describe('_moderateImage', () => {
  it('returns not flagged for clean image', async () => {
    axios.post.mockResolvedValueOnce({
      data: {
        results: [{
          flagged: false,
          categories: { sexual: false },
        }],
      },
    });

    const result = await _moderateImage('https://example.com/img.jpg');
    expect(result.flagged).toBe(false);
    expect(axios.post).toHaveBeenCalledWith(
      'https://api.openai.com/v1/moderations',
      {
        model: 'omni-moderation-latest',
        input: [{ type: 'image_url', image_url: { url: 'https://example.com/img.jpg' } }],
      },
      expect.any(Object),
    );
  });

  it('returns flagged for NSFW image', async () => {
    axios.post.mockResolvedValueOnce({
      data: {
        results: [{
          flagged: true,
          categories: { sexual: true, violence: false },
        }],
      },
    });

    const result = await _moderateImage('https://example.com/nsfw.jpg');
    expect(result.flagged).toBe(true);
    expect(result.categories).toEqual(['sexual']);
  });

  it('returns not flagged for null URL', async () => {
    const result = await _moderateImage(null);
    expect(result.flagged).toBe(false);
  });
});

// ─── onPostCreatedModeration ───────────────────────

describe('onPostCreatedModeration', () => {
  function makeSnap(postId, data) {
    const ref = fakeDb.collection('posts').doc(postId);
    fakeDb._seed(`posts/${postId}`, data);
    return {
      id: postId,
      ref,
      data: () => ({ ...data }),
    };
  }

  it('approves a clean post', async () => {
    axios.post.mockResolvedValueOnce({
      data: { results: [{ flagged: false, categories: {} }] },
    });

    const snap = makeSnap('p1', {
      title: '周末打球',
      description: '一起打篮球吧',
      images: [],
    });

    await onPostCreatedModeration(snap);

    const updated = fakeDb._get('posts/p1');
    expect(updated.moderationStatus).toBe('approved');
    expect(updated.moderationCategories).toEqual([]);
  });

  it('rejects a post with harmful text', async () => {
    axios.post.mockResolvedValueOnce({
      data: {
        results: [{
          flagged: true,
          categories: { hate: true, violence: false },
        }],
      },
    });

    const snap = makeSnap('p2', {
      title: 'harmful content',
      description: 'bad stuff',
      images: [],
    });

    await onPostCreatedModeration(snap);

    const updated = fakeDb._get('posts/p2');
    expect(updated.moderationStatus).toBe('rejected');
    expect(updated.moderationCategories).toContain('hate');
  });

  it('also moderates the first image', async () => {
    // Text check: clean
    axios.post.mockResolvedValueOnce({
      data: { results: [{ flagged: false, categories: {} }] },
    });
    // Image check: flagged
    axios.post.mockResolvedValueOnce({
      data: {
        results: [{
          flagged: true,
          categories: { sexual: true },
        }],
      },
    });

    const snap = makeSnap('p3', {
      title: '正常标题',
      description: '正常描述',
      images: ['https://example.com/bad.jpg'],
    });

    await onPostCreatedModeration(snap);

    const updated = fakeDb._get('posts/p3');
    expect(updated.moderationStatus).toBe('rejected');
    expect(updated.moderationCategories).toContain('sexual');
  });

  it('approves when API fails (graceful degradation)', async () => {
    axios.post.mockRejectedValueOnce(new Error('API timeout'));

    const snap = makeSnap('p4', {
      title: '正常帖子',
      description: '正常描述',
      images: [],
    });

    await onPostCreatedModeration(snap);

    const updated = fakeDb._get('posts/p4');
    expect(updated.moderationStatus).toBe('approved');
    expect(updated.moderationError).toBe('API timeout');
  });
});

// ─── onPostUpdatedModeration ───────────────────────

describe('onPostUpdatedModeration', () => {
  function makeChange(postId, before, after) {
    fakeDb._seed(`posts/${postId}`, after);
    const ref = fakeDb.collection('posts').doc(postId);
    return {
      before: { data: () => ({ ...before }) },
      after: { id: postId, ref, data: () => ({ ...after }) },
    };
  }

  it('re-moderates when title changes', async () => {
    axios.post.mockResolvedValueOnce({
      data: { results: [{ flagged: false, categories: {} }] },
    });

    const change = makeChange('p5',
      { title: '旧标题', description: '描述', moderationStatus: 'approved' },
      { title: '新标题', description: '描述', moderationStatus: 'approved' },
    );

    await onPostUpdatedModeration(change);

    const updated = fakeDb._get('posts/p5');
    expect(updated.moderationStatus).toBe('approved');
  });

  it('skips moderation when title/description unchanged', async () => {
    const change = makeChange('p6',
      { title: '同标题', description: '同描述', moderationStatus: 'approved' },
      { title: '同标题', description: '同描述', moderationStatus: 'approved' },
    );

    await onPostUpdatedModeration(change);
    expect(axios.post).not.toHaveBeenCalled();
  });

  it('skips when moderationStatus itself changed (prevent loop)', async () => {
    const change = makeChange('p7',
      { title: '标题', description: '描述', moderationStatus: 'approved' },
      { title: '标题', description: '描述', moderationStatus: 'rejected' },
    );

    await onPostUpdatedModeration(change);
    expect(axios.post).not.toHaveBeenCalled();
  });
});
