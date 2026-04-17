/**
 * identity.test.js
 * 覆盖：startIdentityVerification + stripeIdentityWebhook
 * Mock 边界：stripe SDK（外部 API）
 */

// ─── Mock stripe SDK ───────────────────────────────
const mockVerificationSessionsCreate = jest.fn();
const mockWebhooksConstructEvent = jest.fn();

jest.mock('stripe', () => {
  return jest.fn().mockImplementation(() => ({
    identity: {
      verificationSessions: {
        create: mockVerificationSessionsCreate,
      },
    },
    webhooks: {
      constructEvent: mockWebhooksConstructEvent,
    },
  }));
});

jest.mock('firebase-admin', () => require('./setup').adminMock);
jest.mock('firebase-admin/firestore', () => require('./setup').firestoreModuleMock);
jest.mock('firebase-functions', () => require('./setup').makeFunctionsMock());

const { fakeDb, makeContext, expectHttpsError } = require('./setup');

// 设置 env 变量（在 require identity.js 之前）
process.env.STRIPE_SECRET_KEY = 'sk_test_fake';
process.env.STRIPE_WEBHOOK_SECRET = 'whsec_test_fake';

const identity = require('../src/identity');

beforeEach(() => {
  fakeDb._clear();
  mockVerificationSessionsCreate.mockReset();
  mockWebhooksConstructEvent.mockReset();
});

// 种子辅助
function seedUser(uid, fields = {}) {
  fakeDb._seed(`users/${uid}`, {
    name: `User ${uid}`,
    verificationLevel: 1,
    ...fields,
  });
}

// ─────────────────────────────────────────────────────
// startIdentityVerification
// ─────────────────────────────────────────────────────
describe('startIdentityVerification', () => {
  test('未认证用户：unauthenticated', async () => {
    await expectHttpsError(
      identity.startIdentityVerification({}, makeContext(null)),
      'unauthenticated'
    );
  });

  test('已验证用户（level >= 2）：already-exists', async () => {
    seedUser('u1', { verificationLevel: 2 });

    await expectHttpsError(
      identity.startIdentityVerification({}, makeContext('u1')),
      'already-exists'
    );
  });

  test('正常用户：创建 session 并返回 clientSecret', async () => {
    seedUser('u1', { verificationLevel: 1 });

    mockVerificationSessionsCreate.mockResolvedValue({
      id: 'vs_test_123',
      client_secret: 'cs_test_secret_456',
    });

    const result = await identity.startIdentityVerification(
      {},
      makeContext('u1')
    );

    expect(result.clientSecret).toBe('cs_test_secret_456');
    expect(result.verificationSessionId).toBe('vs_test_123');
    expect(mockVerificationSessionsCreate).toHaveBeenCalledWith({
      type: 'document',
      metadata: { uid: 'u1' },
    });
  });
});

// ─────────────────────────────────────────────────────
// stripeIdentityWebhook
// ─────────────────────────────────────────────────────
describe('stripeIdentityWebhook', () => {
  // 辅助：构造 fake req/res
  function makeReq(body, headers = {}) {
    return {
      body,
      rawBody: JSON.stringify(body),
      headers: { 'stripe-signature': 'sig_test', ...headers },
    };
  }

  function makeRes() {
    const res = {
      statusCode: null,
      body: null,
      status(code) {
        res.statusCode = code;
        return res;
      },
      send(data) {
        res.body = data;
        return res;
      },
      json(data) {
        res.body = data;
        return res;
      },
    };
    return res;
  }

  test('签名无效：返回 400', async () => {
    mockWebhooksConstructEvent.mockImplementation(() => {
      throw new Error('Invalid signature');
    });

    const req = makeReq({ type: 'test' });
    const res = makeRes();

    await identity.stripeIdentityWebhook(req, res);

    expect(res.statusCode).toBe(400);
  });

  test('verification_session.verified：升级 verificationLevel 为 2', async () => {
    seedUser('u1', { verificationLevel: 1 });

    mockWebhooksConstructEvent.mockReturnValue({
      type: 'identity.verification_session.verified',
      data: {
        object: {
          id: 'vs_test_123',
          metadata: { uid: 'u1' },
        },
      },
    });

    const req = makeReq({});
    const res = makeRes();

    await identity.stripeIdentityWebhook(req, res);

    expect(res.statusCode).toBe(200);
    const userData = fakeDb._get('users/u1');
    expect(userData.verificationLevel).toBe(2);
    expect(userData.verifiedAt).toBeDefined();
  });

  test('未知事件类型：正常返回 200', async () => {
    mockWebhooksConstructEvent.mockReturnValue({
      type: 'some.unknown.event',
      data: { object: {} },
    });

    const req = makeReq({});
    const res = makeRes();

    await identity.stripeIdentityWebhook(req, res);

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({ received: true });
  });
});
