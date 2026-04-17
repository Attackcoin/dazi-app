jest.mock('firebase-admin', () => require('./setup').adminMock);
jest.mock('firebase-admin/firestore', () => require('./setup').firestoreModuleMock);
jest.mock('firebase-functions', () => require('./setup').makeFunctionsMock());

const { fakeDb, makeContext, expectHttpsError } = require('./setup');

const {
  recalcTrustScore,
  getTrustInfo,
  onReviewWrittenTrust,
  onMatchCompletedTrust,
  _calculateTrustScore,
  _getTrustLevel,
} = require('../src/trustScore');

beforeEach(() => {
  fakeDb._clear();
  jest.clearAllMocks();
});

// ─── _calculateTrustScore (纯函数) ─────────────────

describe('_calculateTrustScore', () => {
  it('returns 60 for a brand new user', () => {
    expect(_calculateTrustScore({})).toBe(60);
  });

  it('adds meetup bonus capped at 30', () => {
    // 10 meetups × 2 = +20
    expect(_calculateTrustScore({ totalMeetups: 10 })).toBe(80);
    // 20 meetups × 2 = +40 → capped at +30
    expect(_calculateTrustScore({ totalMeetups: 20 })).toBe(90);
  });

  it('penalizes ghost count at -15 each', () => {
    // 1 ghost → 60 - 15 = 45
    expect(_calculateTrustScore({ ghostCount: 1 })).toBe(45);
    // 4 ghosts → 60 - 60 = 0
    expect(_calculateTrustScore({ ghostCount: 4 })).toBe(0);
  });

  it('adds rating bonus when above 3', () => {
    // avg 4.5 → (4.5 - 3) × 10 = +15
    expect(_calculateTrustScore({ ratingSum: 9, ratingCount: 2 })).toBe(75);
  });

  it('penalizes rating below 3', () => {
    // avg 2.0 → (2 - 3) × 10 = -10
    expect(_calculateTrustScore({ ratingSum: 4, ratingCount: 2 })).toBe(50);
  });

  it('adds verified bonus for level 2+', () => {
    expect(_calculateTrustScore({ verificationLevel: 2 })).toBe(65);
    expect(_calculateTrustScore({ verificationLevel: 3 })).toBe(65);
    // level 1 → no bonus
    expect(_calculateTrustScore({ verificationLevel: 1 })).toBe(60);
  });

  it('clamps to [0, 100]', () => {
    // very active + high rating → capped at 100
    expect(_calculateTrustScore({
      totalMeetups: 50, ratingSum: 50, ratingCount: 10, verificationLevel: 2,
    })).toBe(100);
    // many ghosts → capped at 0
    expect(_calculateTrustScore({ ghostCount: 10 })).toBe(0);
  });

  it('combines all factors correctly', () => {
    // 5 meetups (+10), 1 ghost (-15), avg 4.0 (+10), verified (+5) = 60 + 10 - 15 + 10 + 5 = 70
    const score = _calculateTrustScore({
      totalMeetups: 5,
      ghostCount: 1,
      ratingSum: 12,
      ratingCount: 3,
      verificationLevel: 2,
    });
    expect(score).toBe(70);
  });
});

// ─── _getTrustLevel ─────────────────────────────────

describe('_getTrustLevel', () => {
  it('returns restricted for score < 40', () => {
    expect(_getTrustLevel(0)).toBe('restricted');
    expect(_getTrustLevel(39)).toBe('restricted');
  });

  it('returns normal for score 40-69', () => {
    expect(_getTrustLevel(40)).toBe('normal');
    expect(_getTrustLevel(69)).toBe('normal');
  });

  it('returns trusted for score >= 70', () => {
    expect(_getTrustLevel(70)).toBe('trusted');
    expect(_getTrustLevel(100)).toBe('trusted');
  });
});

// ─── recalcTrustScore ───────────────────────────────

describe('recalcTrustScore', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      recalcTrustScore({}, makeContext(null)),
      'unauthenticated',
    );
  });

  it('rejects missing user', async () => {
    await expectHttpsError(
      recalcTrustScore({}, makeContext('ghost_user')),
      'not-found',
    );
  });

  it('calculates and persists trust score', async () => {
    fakeDb._seed('users/u1', {
      totalMeetups: 5,
      ghostCount: 0,
      ratingSum: 20,
      ratingCount: 4,
      verificationLevel: 2,
    });

    const result = await recalcTrustScore({}, makeContext('u1'));
    expect(result.success).toBe(true);
    expect(result.score).toBe(95); // 60 + 10 + 20 + 5 = 95
    expect(result.level).toBe('trusted');

    // verify persisted
    const user = fakeDb._get('users/u1');
    expect(user.trustScore).toBe(95);
    expect(user.trustLevel).toBe('trusted');
  });

  it('returns restricted level for low score', async () => {
    fakeDb._seed('users/u2', {
      totalMeetups: 0,
      ghostCount: 3,
      ratingSum: 2,
      ratingCount: 1,
      verificationLevel: 1,
    });

    const result = await recalcTrustScore({}, makeContext('u2'));
    // 60 + 0 - 45 + (-10) + 0 = 5
    expect(result.score).toBe(5);
    expect(result.level).toBe('restricted');
  });
});

// ─── getTrustInfo ───────────────────────────────────

describe('getTrustInfo', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      getTrustInfo({}, makeContext(null)),
      'unauthenticated',
    );
  });

  it('returns full breakdown', async () => {
    fakeDb._seed('users/u1', {
      totalMeetups: 10,
      ghostCount: 1,
      ratingSum: 18,
      ratingCount: 4,
      verificationLevel: 2,
    });

    const info = await getTrustInfo({}, makeContext('u1'));
    expect(info.score).toBeGreaterThan(0);
    expect(info.level).toBeDefined();
    expect(info.breakdown.baseScore).toBe(60);
    expect(info.breakdown.meetupBonus).toBe(20);
    expect(info.breakdown.ghostPenalty).toBe(15);
    expect(info.breakdown.verifiedBonus).toBe(5);
    expect(info.stats.totalMeetups).toBe(10);
    expect(info.stats.ghostCount).toBe(1);
    expect(info.stats.avgRating).toBe(4.5);
  });
});

// ─── onReviewWrittenTrust ───────────────────────────

describe('onReviewWrittenTrust', () => {
  it('recalculates trust score on new review', async () => {
    fakeDb._seed('users/u2', {
      totalMeetups: 3,
      ghostCount: 0,
      ratingSum: 12,
      ratingCount: 3,
      verificationLevel: 1,
    });

    const snap = {
      data: () => ({ toUser: 'u2', fromUser: 'u1', rating: 5 }),
    };

    await onReviewWrittenTrust(snap);

    const user = fakeDb._get('users/u2');
    expect(user.trustScore).toBeDefined();
    expect(user.trustLevel).toBeDefined();
  });

  it('does nothing if toUser is missing', async () => {
    const snap = { data: () => ({ fromUser: 'u1', rating: 5 }) };
    // should not throw
    await onReviewWrittenTrust(snap);
  });
});

// ─── onMatchCompletedTrust ──────────────────────────

describe('onMatchCompletedTrust', () => {
  it('recalculates for all participants when match completes', async () => {
    fakeDb._seed('users/u1', { totalMeetups: 5, ghostCount: 0 });
    fakeDb._seed('users/u2', { totalMeetups: 3, ghostCount: 0 });

    const change = {
      before: { data: () => ({ status: 'confirmed', participants: ['u1', 'u2'] }) },
      after: { data: () => ({ status: 'completed', participants: ['u1', 'u2'] }) },
    };

    await onMatchCompletedTrust(change);

    expect(fakeDb._get('users/u1').trustScore).toBeDefined();
    expect(fakeDb._get('users/u2').trustScore).toBeDefined();
  });

  it('skips if status did not change to trigger state', async () => {
    fakeDb._seed('users/u1', { totalMeetups: 1 });

    const change = {
      before: { data: () => ({ status: 'confirmed', participants: ['u1'] }) },
      after: { data: () => ({ status: 'confirmed', participants: ['u1'] }) },
    };

    await onMatchCompletedTrust(change);
    // trustScore should NOT be set
    expect(fakeDb._get('users/u1').trustScore).toBeUndefined();
  });

  it('skips if already in completed state before', async () => {
    fakeDb._seed('users/u1', { totalMeetups: 1 });

    const change = {
      before: { data: () => ({ status: 'completed', participants: ['u1'] }) },
      after: { data: () => ({ status: 'completed', participants: ['u1'] }) },
    };

    await onMatchCompletedTrust(change);
    expect(fakeDb._get('users/u1').trustScore).toBeUndefined();
  });
});
