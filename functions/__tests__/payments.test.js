jest.mock('firebase-admin', () => require('./setup').adminMock);
jest.mock('firebase-admin/firestore', () => require('./setup').firestoreModuleMock);
jest.mock('firebase-functions', () => require('./setup').makeFunctionsMock());
jest.mock('stripe', () => {
  return () => ({
    checkout: {
      sessions: {
        create: jest.fn().mockResolvedValue({
          id: 'sess_test_123',
          url: 'https://checkout.stripe.com/test',
        }),
      },
    },
    webhooks: {
      constructEvent: jest.fn((body, sig, secret) => JSON.parse(body)),
    },
  });
});

const { fakeDb, makeContext, expectHttpsError } = require('./setup');

process.env.STRIPE_SECRET_KEY = 'sk_test_xxx';

const {
  createPaymentSession,
  settlePayments,
} = require('../src/payments');

beforeEach(() => {
  fakeDb._clear();
  jest.clearAllMocks();
});

// ─── createPaymentSession ──────────────────────────

describe('createPaymentSession', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      createPaymentSession({ postId: 'p1' }, makeContext(null)),
      'unauthenticated',
    );
  });

  it('requires postId', async () => {
    await expectHttpsError(
      createPaymentSession({}, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('requires existing post', async () => {
    await expectHttpsError(
      createPaymentSession({ postId: 'nonexistent' }, makeContext('u1')),
      'not-found',
    );
  });

  it('rejects if no participation fee', async () => {
    fakeDb._seed('posts/p1', {
      title: '免费活动',
      userId: 'u2',
      participationFee: 0,
    });

    await expectHttpsError(
      createPaymentSession({ postId: 'p1' }, makeContext('u1')),
      'failed-precondition',
    );
  });

  it('rejects if publisher tries to pay', async () => {
    fakeDb._seed('posts/p1', {
      title: '付费活动',
      userId: 'u1',
      participationFee: 5,
    });

    await expectHttpsError(
      createPaymentSession({ postId: 'p1' }, makeContext('u1')),
      'permission-denied',
    );
  });

  it('creates checkout session for valid request', async () => {
    fakeDb._seed('posts/p1', {
      title: '付费篮球局',
      category: '运动',
      userId: 'publisher1',
      participationFee: 5,
    });

    const result = await createPaymentSession(
      { postId: 'p1' },
      makeContext('participant1'),
    );

    expect(result.checkoutUrl).toBe('https://checkout.stripe.com/test');

    // Check payment record was created
    const payment = fakeDb._get('activityPayments/p1_participant1');
    expect(payment).toBeDefined();
    expect(payment.status).toBe('pending');
    expect(payment.amount).toBe(5);
    expect(payment.publisherId).toBe('publisher1');
    expect(payment.platformFeeCents).toBe(75); // 500 * 15% = 75
    expect(payment.publisherAmountCents).toBe(425); // 500 - 75
  });

  it('returns alreadyPaid for paid payment', async () => {
    fakeDb._seed('posts/p1', {
      title: '付费活动',
      userId: 'pub',
      participationFee: 5,
    });
    fakeDb._seed('activityPayments/p1_u1', {
      status: 'paid',
    });

    const result = await createPaymentSession(
      { postId: 'p1' },
      makeContext('u1'),
    );

    expect(result.alreadyPaid).toBe(true);
  });

  it('returns existing session for pending payment', async () => {
    fakeDb._seed('posts/p1', {
      title: '付费活动',
      userId: 'pub',
      participationFee: 5,
    });
    fakeDb._seed('activityPayments/p1_u1', {
      status: 'pending',
      checkoutUrl: 'https://stripe.com/existing',
    });

    const result = await createPaymentSession(
      { postId: 'p1' },
      makeContext('u1'),
    );

    expect(result.checkoutUrl).toBe('https://stripe.com/existing');
    expect(result.resumed).toBe(true);
  });
});

// ─── settlePayments ────────────────────────────────

describe('settlePayments', () => {
  it('settles payments for completed matches', async () => {
    fakeDb._seed('activityPayments/pay1', {
      postId: 'p1',
      uid: 'u1',
      publisherId: 'pub1',
      status: 'paid',
      publisherAmountCents: 425,
    });
    fakeDb._seed('matches/m1', {
      postId: 'p1',
      status: 'completed',
    });

    await settlePayments();

    const payment = fakeDb._get('activityPayments/pay1');
    expect(payment.status).toBe('settled');
  });

  it('skips payments for incomplete matches', async () => {
    fakeDb._seed('activityPayments/pay2', {
      postId: 'p2',
      uid: 'u1',
      publisherId: 'pub1',
      status: 'paid',
    });
    fakeDb._seed('matches/m2', {
      postId: 'p2',
      status: 'confirmed', // not completed
    });

    await settlePayments();

    const payment = fakeDb._get('activityPayments/pay2');
    expect(payment.status).toBe('paid'); // unchanged
  });
});
