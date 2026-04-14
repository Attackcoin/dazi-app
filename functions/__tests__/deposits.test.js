/**
 * deposits.test.js
 * 覆盖 H-7 (freezeDeposit 确定性 id + CAS / depositPaymentCallback CAS)
 */

jest.mock('firebase-admin', () => require('./setup').adminMock);
jest.mock('firebase-functions', () => require('./setup').makeFunctionsMock());

const { fakeDb, makeContext, expectHttpsError } = require('./setup');
const deposits = require('../src/deposits');

beforeEach(() => {
  fakeDb._clear();
  process.env.PAYMENT_CALLBACK_SECRET = 'testsecret';
});

function seedUser(uid, fields = {}) {
  fakeDb._seed(`users/${uid}`, {
    name: uid,
    sesameAuthorized: false,
    ...fields,
  });
}

function seedMatch(matchId, participants) {
  fakeDb._seed(`matches/${matchId}`, {
    postId: 'p1',
    participants,
  });
}

function seedPost(postId, depositAmount) {
  fakeDb._seed(`posts/${postId}`, {
    depositAmount,
  });
}

// ─────────────────────────────────────────────────────
// freezeDeposit
// ─────────────────────────────────────────────────────
describe('freezeDeposit (H-7 确定性 id + 幂等)', () => {
  test('首次冻结：创建 deposits/{matchId}_{uid}, status=pending_payment', async () => {
    seedUser('u1');
    seedMatch('m1', ['u1', 'u2']);
    seedPost('p1', 50);

    const r = await deposits.freezeDeposit(
      { matchId: 'm1', payChannel: 'wechat' },
      makeContext('u1')
    );
    expect(r.success).toBe(true);
    const dep = fakeDb._get('deposits/m1_u1');
    expect(dep).toBeDefined();
    expect(dep.status).toBe('pending_payment');
    expect(dep.amount).toBe(50);
    expect(dep.payChannel).toBe('wechat');
  });

  test('第二次 freeze（当前 pending_payment）：复用 orderId, resumed=true', async () => {
    seedUser('u1');
    seedMatch('m1', ['u1', 'u2']);
    seedPost('p1', 50);
    fakeDb._seed('deposits/m1_u1', {
      userId: 'u1',
      matchId: 'm1',
      amount: 50,
      status: 'pending_payment',
      payChannel: 'wechat',
      orderId: 'original_order_123',
    });

    const r = await deposits.freezeDeposit(
      { matchId: 'm1', payChannel: 'wechat' },
      makeContext('u1')
    );
    expect(r.resumed).toBe(true);
    expect(r.orderId).toBe('original_order_123');
  });

  test('当前已 frozen：返回 alreadyFrozen', async () => {
    seedUser('u1');
    seedMatch('m1', ['u1', 'u2']);
    seedPost('p1', 50);
    fakeDb._seed('deposits/m1_u1', {
      userId: 'u1',
      matchId: 'm1',
      amount: 50,
      status: 'frozen',
      payChannel: 'wechat',
    });

    const r = await deposits.freezeDeposit(
      { matchId: 'm1', payChannel: 'wechat' },
      makeContext('u1')
    );
    expect(r.alreadyFrozen).toBe(true);
  });

  test('当前 refunded：failed-precondition', async () => {
    seedUser('u1');
    seedMatch('m1', ['u1', 'u2']);
    seedPost('p1', 50);
    fakeDb._seed('deposits/m1_u1', {
      userId: 'u1',
      matchId: 'm1',
      status: 'refunded',
      payChannel: 'wechat',
    });

    await expectHttpsError(
      deposits.freezeDeposit(
        { matchId: 'm1', payChannel: 'wechat' },
        makeContext('u1')
      ),
      'failed-precondition'
    );
  });

  test('芝麻信用用户：sesame_guaranteed, 不需支付', async () => {
    seedUser('u1', { sesameAuthorized: true });
    seedMatch('m1', ['u1', 'u2']);
    seedPost('p1', 50);

    const r = await deposits.freezeDeposit(
      { matchId: 'm1', payChannel: 'wechat' },
      makeContext('u1')
    );
    expect(r.method).toBe('sesame');
    expect(fakeDb._get('deposits/m1_u1').status).toBe('sesame_guaranteed');
  });

  test('无押金要求：success message', async () => {
    seedUser('u1');
    seedMatch('m1', ['u1', 'u2']);
    seedPost('p1', 0);

    const r = await deposits.freezeDeposit(
      { matchId: 'm1', payChannel: 'wechat' },
      makeContext('u1')
    );
    expect(r.success).toBe(true);
    expect(fakeDb._get('deposits/m1_u1')).toBeUndefined();
  });

  test('非参与者：permission-denied', async () => {
    seedUser('stranger');
    seedMatch('m1', ['u1', 'u2']);
    seedPost('p1', 50);

    await expectHttpsError(
      deposits.freezeDeposit(
        { matchId: 'm1', payChannel: 'wechat' },
        makeContext('stranger')
      ),
      'permission-denied'
    );
  });

  test('非法 payChannel：invalid-argument', async () => {
    seedUser('u1');
    seedMatch('m1', ['u1', 'u2']);
    seedPost('p1', 50);

    await expectHttpsError(
      deposits.freezeDeposit(
        { matchId: 'm1', payChannel: 'bitcoin' },
        makeContext('u1')
      ),
      'invalid-argument'
    );
  });
});
