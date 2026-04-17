jest.mock('firebase-admin', () => require('./setup').adminMock);
jest.mock('firebase-admin/firestore', () => require('./setup').firestoreModuleMock);
jest.mock('firebase-functions', () => require('./setup').makeFunctionsMock());

const { fakeDb, makeContext, expectHttpsError } = require('./setup');

const {
  registerVenue,
  listNearbyVenues,
  venueCheckin,
  settleVenueCommission,
} = require('../src/venues');

beforeEach(() => {
  fakeDb._clear();
  jest.clearAllMocks();
});

// ─── registerVenue ────────────────────────────────

describe('registerVenue', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      registerVenue({ name: '星巴克', address: '南京路100号' }, makeContext(null)),
      'unauthenticated',
    );
  });

  it('requires name', async () => {
    await expectHttpsError(
      registerVenue({ address: '地址' }, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('rejects empty name', async () => {
    await expectHttpsError(
      registerVenue({ name: '   ', address: '地址' }, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('rejects name over 50 chars', async () => {
    await expectHttpsError(
      registerVenue({ name: 'a'.repeat(51), address: '地址' }, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('requires address', async () => {
    await expectHttpsError(
      registerVenue({ name: '星巴克' }, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('registers venue in pending_review status', async () => {
    const result = await registerVenue({
      name: '星巴克臻选',
      description: '精品咖啡',
      category: '咖啡厅',
      address: '南京西路1266号',
      lat: 31.2304,
      lng: 121.4737,
      contactName: '张经理',
      contactPhone: '13800001111',
      perks: ['搭子用户9折', '免费WiFi'],
    }, makeContext('u1'));

    expect(result.success).toBe(true);
    expect(result.venueId).toBeTruthy();
    expect(result.status).toBe('pending_review');

    const venue = fakeDb._get(`venues/${result.venueId}`);
    expect(venue.name).toBe('星巴克臻选');
    expect(venue.category).toBe('咖啡厅');
    expect(venue.address).toBe('南京西路1266号');
    expect(venue.isActive).toBe(false);
    expect(venue.ownerId).toBe('u1');
    expect(venue.totalCheckins).toBe(0);
    expect(venue.perks).toEqual(['搭子用户9折', '免费WiFi']);
    expect(venue.commissionRate).toBe(0.10);
  });

  it('caps perks at 5', async () => {
    const result = await registerVenue({
      name: '场地',
      address: '地址',
      perks: ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
    }, makeContext('u1'));

    const venue = fakeDb._get(`venues/${result.venueId}`);
    expect(venue.perks.length).toBe(5);
  });
});

// ─── listNearbyVenues ─────────────────────────────

describe('listNearbyVenues', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      listNearbyVenues({}, makeContext(null)),
      'unauthenticated',
    );
  });

  it('returns only active venues', async () => {
    fakeDb._seed('venues/v1', { name: '星巴克', isActive: true, totalCheckins: 10, category: '咖啡厅' });
    fakeDb._seed('venues/v2', { name: '待审核', isActive: false, totalCheckins: 0, category: '咖啡厅' });

    const result = await listNearbyVenues({}, makeContext('u1'));
    expect(result.venues.length).toBe(1);
    expect(result.venues[0].name).toBe('星巴克');
  });

  it('filters by category', async () => {
    fakeDb._seed('venues/v1', { name: '星巴克', isActive: true, totalCheckins: 5, category: '咖啡厅' });
    fakeDb._seed('venues/v2', { name: '健身房', isActive: true, totalCheckins: 3, category: '健身' });

    const result = await listNearbyVenues({ category: '健身' }, makeContext('u1'));
    expect(result.venues.length).toBe(1);
    expect(result.venues[0].name).toBe('健身房');
  });
});

// ─── venueCheckin ─────────────────────────────────

describe('venueCheckin', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      venueCheckin({ venueId: 'v1' }, makeContext(null)),
      'unauthenticated',
    );
  });

  it('requires venueId', async () => {
    await expectHttpsError(
      venueCheckin({}, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('rejects non-existent venue', async () => {
    await expectHttpsError(
      venueCheckin({ venueId: 'ghost' }, makeContext('u1')),
      'not-found',
    );
  });

  it('rejects inactive venue', async () => {
    fakeDb._seed('venues/v1', { name: '待审核', isActive: false });
    await expectHttpsError(
      venueCheckin({ venueId: 'v1' }, makeContext('u1')),
      'failed-precondition',
    );
  });

  it('checks in and increments totalCheckins', async () => {
    fakeDb._seed('venues/v1', {
      name: '星巴克',
      isActive: true,
      commissionRate: 0.15,
      totalCheckins: 5,
      perks: ['9折优惠'],
    });

    const result = await venueCheckin(
      { venueId: 'v1', matchId: 'm1', postId: 'p1' },
      makeContext('u1'),
    );

    expect(result.success).toBe(true);
    expect(result.perks).toEqual(['9折优惠']);

    // totalCheckins +1
    const venue = fakeDb._get('venues/v1');
    expect(venue.totalCheckins).toBe(6);

    // checkin doc created
    const checkin = fakeDb._get('venues/v1/checkins/v1_u1_m1');
    expect(checkin.uid).toBe('u1');
    expect(checkin.matchId).toBe('m1');
    expect(checkin.commissionAmount).toBe(0.15);
    expect(checkin.settled).toBe(false);
  });

  it('is idempotent — already checked in', async () => {
    fakeDb._seed('venues/v1', { name: '星巴克', isActive: true, totalCheckins: 5 });
    fakeDb._seed('venues/v1/checkins/v1_u1_m1', { uid: 'u1', settled: false });

    const result = await venueCheckin(
      { venueId: 'v1', matchId: 'm1' },
      makeContext('u1'),
    );

    expect(result.success).toBe(true);
    expect(result.alreadyCheckedIn).toBe(true);

    // totalCheckins unchanged
    expect(fakeDb._get('venues/v1').totalCheckins).toBe(5);
  });

  it('handles walk-in (no matchId)', async () => {
    fakeDb._seed('venues/v1', { name: '星巴克', isActive: true, totalCheckins: 0 });

    const result = await venueCheckin({ venueId: 'v1' }, makeContext('u1'));
    expect(result.success).toBe(true);

    const checkin = fakeDb._get('venues/v1/checkins/v1_u1_walk_in');
    expect(checkin.uid).toBe('u1');
    expect(checkin.matchId).toBe('');
  });
});

// ─── settleVenueCommission ────────────────────────

describe('settleVenueCommission', () => {
  it('settles unsettled checkins and updates totalRevenue', async () => {
    fakeDb._seed('venues/v1', { name: '星巴克', isActive: true, totalRevenue: 0 });
    fakeDb._seed('venues/v1/checkins/c1', { uid: 'u1', commissionAmount: 0.10, settled: false });
    fakeDb._seed('venues/v1/checkins/c2', { uid: 'u2', commissionAmount: 0.10, settled: false });
    fakeDb._seed('venues/v1/checkins/c3', { uid: 'u3', commissionAmount: 0.10, settled: true }); // already settled

    await settleVenueCommission();

    // c1 and c2 settled
    expect(fakeDb._get('venues/v1/checkins/c1').settled).toBe(true);
    expect(fakeDb._get('venues/v1/checkins/c2').settled).toBe(true);
    // c3 was already settled
    expect(fakeDb._get('venues/v1/checkins/c3').settled).toBe(true);

    // totalRevenue incremented
    const venue = fakeDb._get('venues/v1');
    expect(venue.totalRevenue).toBeCloseTo(0.20, 2);
  });

  it('handles no unsettled checkins gracefully', async () => {
    fakeDb._seed('venues/v1', { name: '星巴克', isActive: true, totalRevenue: 1.0 });

    // no checkins at all — should not throw
    await settleVenueCommission();
    expect(fakeDb._get('venues/v1').totalRevenue).toBe(1.0);
  });
});
