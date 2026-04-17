/**
 * safety.test.js
 * 覆盖 T5-12 AI 安全伴侣：confirmSafety + escalateSafetyAlert + _createSafetyAlert
 */

jest.mock('firebase-admin', () => require('./setup').adminMock);
jest.mock('firebase-admin/firestore', () => require('./setup').firestoreModuleMock);
jest.mock('firebase-functions', () => require('./setup').makeFunctionsMock());
jest.mock('../src/notifications', () => ({
  _sendNotification: jest.fn().mockResolvedValue(undefined),
}));

const { fakeDb, makeContext, expectHttpsError } = require('./setup');
const { firestoreModuleMock } = require('./setup');
const safety = require('../src/safety');
const { _sendNotification } = require('../src/notifications');

beforeEach(() => {
  fakeDb._clear();
  _sendNotification.mockClear();
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

function seedSafetyAlert(alertId, fields = {}) {
  fakeDb._seed(`safetyAlerts/${alertId}`, {
    matchId: 'm1',
    uid: 'u1',
    emergencyContacts: [{ name: '妈妈', phone: '13800001111' }],
    status: 'pending',
    createdAt: new Date(),
    expiresAt: firestoreModuleMock.Timestamp.fromDate(
      new Date(Date.now() + 30 * 60 * 1000)
    ),
    ...fields,
  });
}

// ─────────────────────────────────────────────────────
// confirmSafety
// ─────────────────────────────────────────────────────
describe('confirmSafety', () => {
  test('未认证拒绝：unauthenticated', async () => {
    await expectHttpsError(
      safety.confirmSafety({}, makeContext(null)),
      'unauthenticated'
    );
  });

  test('无 pending alert 时返回 not-found', async () => {
    seedUser('u1');
    await expectHttpsError(
      safety.confirmSafety({}, makeContext('u1')),
      'not-found'
    );
  });

  test('正常确认，status 变 confirmed', async () => {
    seedUser('u1');
    seedSafetyAlert('m1_u1', { uid: 'u1' });

    const r = await safety.confirmSafety({}, makeContext('u1'));
    expect(r.success).toBe(true);

    const alert = fakeDb._get('safetyAlerts/m1_u1');
    expect(alert.status).toBe('confirmed');
    expect(alert.confirmedAt).toBeDefined();
  });

  test('已确认的 alert 不会再被查到（status 不是 pending）', async () => {
    seedUser('u1');
    seedSafetyAlert('m1_u1', { uid: 'u1', status: 'confirmed' });

    await expectHttpsError(
      safety.confirmSafety({}, makeContext('u1')),
      'not-found'
    );
  });

  test('其他用户的 pending alert 不会被当前用户确认', async () => {
    seedUser('u1');
    seedUser('u2');
    seedSafetyAlert('m1_u2', { uid: 'u2' });

    await expectHttpsError(
      safety.confirmSafety({}, makeContext('u1')),
      'not-found'
    );
  });
});

// ─────────────────────────────────────────────────────
// escalateSafetyAlert
// ─────────────────────────────────────────────────────
describe('escalateSafetyAlert', () => {
  test('过期未确认的 alert 被 escalate', async () => {
    seedUser('u1');
    // expiresAt 设为过去时间（已过期）
    seedSafetyAlert('m1_u1', {
      uid: 'u1',
      expiresAt: firestoreModuleMock.Timestamp.fromDate(
        new Date(Date.now() - 5 * 60 * 1000)
      ),
    });

    await safety.escalateSafetyAlert();

    const alert = fakeDb._get('safetyAlerts/m1_u1');
    expect(alert.status).toBe('escalated');
    expect(alert.escalatedAt).toBeDefined();

    // 应该给用户发了强提醒推送
    expect(_sendNotification).toHaveBeenCalledWith(
      'u1',
      '你的紧急联系人已被通知',
      '你的紧急联系人已被通知。如有误触请联系客服。',
      expect.objectContaining({ type: 'safety_escalated', matchId: 'm1' })
    );
  });

  test('未过期的 alert 不被处理', async () => {
    seedUser('u1');
    // expiresAt 设为未来时间（未过期）
    seedSafetyAlert('m1_u1', {
      uid: 'u1',
      expiresAt: firestoreModuleMock.Timestamp.fromDate(
        new Date(Date.now() + 20 * 60 * 1000)
      ),
    });

    await safety.escalateSafetyAlert();

    const alert = fakeDb._get('safetyAlerts/m1_u1');
    expect(alert.status).toBe('pending');
    expect(alert.escalatedAt).toBeUndefined();
    expect(_sendNotification).not.toHaveBeenCalled();
  });

  test('已确认的 alert 不被 escalate', async () => {
    seedUser('u1');
    seedSafetyAlert('m1_u1', {
      uid: 'u1',
      status: 'confirmed',
      expiresAt: firestoreModuleMock.Timestamp.fromDate(
        new Date(Date.now() - 5 * 60 * 1000)
      ),
    });

    await safety.escalateSafetyAlert();

    const alert = fakeDb._get('safetyAlerts/m1_u1');
    expect(alert.status).toBe('confirmed');
    expect(_sendNotification).not.toHaveBeenCalled();
  });

  test('多条过期 alert 全部被 escalate', async () => {
    seedUser('u1');
    seedUser('u2');
    const pastExpiry = firestoreModuleMock.Timestamp.fromDate(
      new Date(Date.now() - 10 * 60 * 1000)
    );
    seedSafetyAlert('m1_u1', { uid: 'u1', expiresAt: pastExpiry });
    seedSafetyAlert('m2_u2', {
      matchId: 'm2', uid: 'u2', expiresAt: pastExpiry,
      emergencyContacts: [{ name: '爸爸', phone: '13800002222' }],
    });

    await safety.escalateSafetyAlert();

    expect(fakeDb._get('safetyAlerts/m1_u1').status).toBe('escalated');
    expect(fakeDb._get('safetyAlerts/m2_u2').status).toBe('escalated');
    expect(_sendNotification).toHaveBeenCalledTimes(2);
  });
});

// ─────────────────────────────────────────────────────
// _createSafetyAlert（内部函数，被 antiGhosting 调用）
// ─────────────────────────────────────────────────────
describe('_createSafetyAlert', () => {
  test('有紧急联系人的用户：创建 alert + 发推送', async () => {
    seedUser('u1', {
      emergencyContacts: [{ name: '妈妈', phone: '13800001111' }],
    });

    await safety._createSafetyAlert('m1', 'u1');

    const alert = fakeDb._get('safetyAlerts/m1_u1');
    expect(alert).toBeDefined();
    expect(alert.matchId).toBe('m1');
    expect(alert.uid).toBe('u1');
    expect(alert.status).toBe('pending');
    expect(alert.emergencyContacts).toEqual([{ name: '妈妈', phone: '13800001111' }]);
    expect(alert.expiresAt).toBeDefined();

    expect(_sendNotification).toHaveBeenCalledWith(
      'u1',
      '你的搭子活动安全确认',
      '你参加的活动已结束但未签到。如果你安全，请忽略此消息。',
      expect.objectContaining({ type: 'safety_check', matchId: 'm1' })
    );
  });

  test('无紧急联系人的用户：不创建 alert', async () => {
    seedUser('u1'); // 无 emergencyContacts

    await safety._createSafetyAlert('m1', 'u1');

    const alert = fakeDb._get('safetyAlerts/m1_u1');
    expect(alert).toBeUndefined();
    expect(_sendNotification).not.toHaveBeenCalled();
  });

  test('空 emergencyContacts 数组：不创建 alert', async () => {
    seedUser('u1', { emergencyContacts: [] });

    await safety._createSafetyAlert('m1', 'u1');

    expect(fakeDb._get('safetyAlerts/m1_u1')).toBeUndefined();
    expect(_sendNotification).not.toHaveBeenCalled();
  });

  test('用户不存在：静默跳过', async () => {
    await safety._createSafetyAlert('m1', 'nonexistent');

    expect(fakeDb._get('safetyAlerts/m1_nonexistent')).toBeUndefined();
    expect(_sendNotification).not.toHaveBeenCalled();
  });

  test('幂等：已存在的 alert 不重复创建', async () => {
    seedUser('u1', {
      emergencyContacts: [{ name: '妈妈', phone: '13800001111' }],
    });
    seedSafetyAlert('m1_u1', { uid: 'u1', status: 'pending' });

    await safety._createSafetyAlert('m1', 'u1');

    // 不应重复发推送
    expect(_sendNotification).not.toHaveBeenCalled();
  });
});
