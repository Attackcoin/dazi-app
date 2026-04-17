jest.mock('firebase-admin', () => require('./setup').adminMock);
jest.mock('firebase-admin/firestore', () => require('./setup').firestoreModuleMock);
jest.mock('firebase-functions', () => require('./setup').makeFunctionsMock());

const { fakeDb, makeContext, expectHttpsError } = require('./setup');

const {
  createVoiceRoom,
  joinVoiceRoom,
  leaveVoiceRoom,
  endVoiceRoom,
  listVoiceRooms,
} = require('../src/voiceRooms');

beforeEach(() => {
  fakeDb._clear();
  jest.clearAllMocks();
});

// ─── createVoiceRoom ─────────────────────────────────

describe('createVoiceRoom', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      createVoiceRoom({ title: '聊天室' }, makeContext(null)),
      'unauthenticated',
    );
  });

  it('requires title', async () => {
    await expectHttpsError(
      createVoiceRoom({}, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('rejects empty title', async () => {
    await expectHttpsError(
      createVoiceRoom({ title: '   ' }, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('rejects title over 50 chars', async () => {
    await expectHttpsError(
      createVoiceRoom({ title: 'a'.repeat(51) }, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('rejects topic over 200 chars', async () => {
    await expectHttpsError(
      createVoiceRoom({ title: '房间', topic: 'x'.repeat(201) }, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('creates a live voice room with host as participant+speaker', async () => {
    fakeDb._seed('users/u1', { name: '张三', avatar: 'https://img/a.jpg' });

    const result = await createVoiceRoom({
      title: '周末闲聊',
      topic: '聊聊最近看的电影',
      category: '闲聊',
      maxParticipants: 6,
    }, makeContext('u1'));

    expect(result.success).toBe(true);
    expect(result.roomId).toBeTruthy();

    const room = fakeDb._get(`voiceRooms/${result.roomId}`);
    expect(room.title).toBe('周末闲聊');
    expect(room.topic).toBe('聊聊最近看的电影');
    expect(room.category).toBe('闲聊');
    expect(room.hostId).toBe('u1');
    expect(room.hostName).toBe('张三');
    expect(room.hostAvatar).toBe('https://img/a.jpg');
    expect(room.maxParticipants).toBe(6);
    expect(room.participants).toEqual(['u1']);
    expect(room.speakerIds).toEqual(['u1']);
    expect(room.participantCount).toBe(1);
    expect(room.isLive).toBe(true);
  });

  it('caps maxParticipants at 20', async () => {
    fakeDb._seed('users/u1', { name: '张三' });

    const result = await createVoiceRoom({
      title: '大房间',
      maxParticipants: 100,
    }, makeContext('u1'));

    const room = fakeDb._get(`voiceRooms/${result.roomId}`);
    expect(room.maxParticipants).toBe(20);
  });

  it('defaults maxParticipants to 8', async () => {
    fakeDb._seed('users/u1', { name: '张三' });

    const result = await createVoiceRoom({
      title: '默认房间',
    }, makeContext('u1'));

    const room = fakeDb._get(`voiceRooms/${result.roomId}`);
    expect(room.maxParticipants).toBe(8);
  });
});

// ─── joinVoiceRoom ────────────────────────────────────

describe('joinVoiceRoom', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      joinVoiceRoom({ roomId: 'r1' }, makeContext(null)),
      'unauthenticated',
    );
  });

  it('requires roomId', async () => {
    await expectHttpsError(
      joinVoiceRoom({}, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('rejects non-existent room', async () => {
    await expectHttpsError(
      joinVoiceRoom({ roomId: 'ghost' }, makeContext('u1')),
      'not-found',
    );
  });

  it('rejects ended room', async () => {
    fakeDb._seed('voiceRooms/r1', {
      title: '已结束', isLive: false, participants: [], maxParticipants: 8,
    });
    await expectHttpsError(
      joinVoiceRoom({ roomId: 'r1' }, makeContext('u2')),
      'failed-precondition',
    );
  });

  it('joins room successfully', async () => {
    fakeDb._seed('voiceRooms/r1', {
      title: '聊天室', isLive: true,
      participants: ['u1'], maxParticipants: 8, participantCount: 1,
    });

    const result = await joinVoiceRoom({ roomId: 'r1' }, makeContext('u2'));
    expect(result.success).toBe(true);

    const room = fakeDb._get('voiceRooms/r1');
    expect(room.participants).toContain('u2');
    expect(room.participantCount).toBe(2);
  });

  it('is idempotent — already joined', async () => {
    fakeDb._seed('voiceRooms/r1', {
      title: '聊天室', isLive: true,
      participants: ['u1', 'u2'], maxParticipants: 8, participantCount: 2,
    });

    const result = await joinVoiceRoom({ roomId: 'r1' }, makeContext('u2'));
    expect(result.success).toBe(true);
    expect(result.alreadyJoined).toBe(true);
    // participantCount unchanged
    expect(fakeDb._get('voiceRooms/r1').participantCount).toBe(2);
  });

  it('rejects when room is full', async () => {
    fakeDb._seed('voiceRooms/r1', {
      title: '满房', isLive: true,
      participants: ['u1', 'u2'], maxParticipants: 2, participantCount: 2,
    });

    await expectHttpsError(
      joinVoiceRoom({ roomId: 'r1' }, makeContext('u3')),
      'resource-exhausted',
    );
  });
});

// ─── leaveVoiceRoom ───────────────────────────────────

describe('leaveVoiceRoom', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      leaveVoiceRoom({ roomId: 'r1' }, makeContext(null)),
      'unauthenticated',
    );
  });

  it('requires roomId', async () => {
    await expectHttpsError(
      leaveVoiceRoom({}, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('handles user not in room gracefully', async () => {
    fakeDb._seed('voiceRooms/r1', {
      title: '聊天室', isLive: true,
      hostId: 'u1', participants: ['u1'], speakerIds: ['u1'], participantCount: 1,
    });

    const result = await leaveVoiceRoom({ roomId: 'r1' }, makeContext('u3'));
    expect(result.success).toBe(true);
    expect(result.notInRoom).toBe(true);
  });

  it('non-host leaves without ending room', async () => {
    fakeDb._seed('voiceRooms/r1', {
      title: '聊天室', isLive: true,
      hostId: 'u1', participants: ['u1', 'u2'], speakerIds: ['u1', 'u2'],
      participantCount: 2,
    });

    const result = await leaveVoiceRoom({ roomId: 'r1' }, makeContext('u2'));
    expect(result.success).toBe(true);
    expect(result.roomEnded).toBeUndefined();

    const room = fakeDb._get('voiceRooms/r1');
    expect(room.isLive).toBe(true);
    expect(room.participants).not.toContain('u2');
    expect(room.speakerIds).not.toContain('u2');
    expect(room.participantCount).toBe(1);
  });

  it('host leaving ends the room', async () => {
    fakeDb._seed('voiceRooms/r1', {
      title: '聊天室', isLive: true,
      hostId: 'u1', participants: ['u1', 'u2'], speakerIds: ['u1'],
      participantCount: 2,
    });

    const result = await leaveVoiceRoom({ roomId: 'r1' }, makeContext('u1'));
    expect(result.success).toBe(true);
    expect(result.roomEnded).toBe(true);

    const room = fakeDb._get('voiceRooms/r1');
    expect(room.isLive).toBe(false);
    expect(room.participants).toEqual([]);
    expect(room.participantCount).toBe(0);
  });
});

// ─── endVoiceRoom ─────────────────────────────────────

describe('endVoiceRoom', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      endVoiceRoom({ roomId: 'r1' }, makeContext(null)),
      'unauthenticated',
    );
  });

  it('requires roomId', async () => {
    await expectHttpsError(
      endVoiceRoom({}, makeContext('u1')),
      'invalid-argument',
    );
  });

  it('rejects non-host', async () => {
    fakeDb._seed('voiceRooms/r1', {
      title: '聊天室', isLive: true, hostId: 'u1',
      participants: ['u1', 'u2'], participantCount: 2,
    });

    await expectHttpsError(
      endVoiceRoom({ roomId: 'r1' }, makeContext('u2')),
      'permission-denied',
    );
  });

  it('host ends room', async () => {
    fakeDb._seed('voiceRooms/r1', {
      title: '聊天室', isLive: true, hostId: 'u1',
      participants: ['u1', 'u2'], speakerIds: ['u1'], participantCount: 2,
    });

    const result = await endVoiceRoom({ roomId: 'r1' }, makeContext('u1'));
    expect(result.success).toBe(true);

    const room = fakeDb._get('voiceRooms/r1');
    expect(room.isLive).toBe(false);
    expect(room.participants).toEqual([]);
    expect(room.participantCount).toBe(0);
  });

  it('is idempotent — already ended', async () => {
    fakeDb._seed('voiceRooms/r1', {
      title: '聊天室', isLive: false, hostId: 'u1',
      participants: [], participantCount: 0,
    });

    const result = await endVoiceRoom({ roomId: 'r1' }, makeContext('u1'));
    expect(result.success).toBe(true);
    expect(result.alreadyEnded).toBe(true);
  });
});

// ─── listVoiceRooms ───────────────────────────────────

describe('listVoiceRooms', () => {
  it('requires auth', async () => {
    await expectHttpsError(
      listVoiceRooms({}, makeContext(null)),
      'unauthenticated',
    );
  });

  it('returns only live rooms', async () => {
    fakeDb._seed('voiceRooms/r1', { title: '直播中', isLive: true, participantCount: 5, category: '闲聊' });
    fakeDb._seed('voiceRooms/r2', { title: '已结束', isLive: false, participantCount: 0, category: '闲聊' });

    const result = await listVoiceRooms({}, makeContext('u1'));
    expect(result.rooms.length).toBe(1);
    expect(result.rooms[0].title).toBe('直播中');
  });

  it('filters by category', async () => {
    fakeDb._seed('voiceRooms/r1', { title: '闲聊房', isLive: true, participantCount: 3, category: '闲聊' });
    fakeDb._seed('voiceRooms/r2', { title: '音乐房', isLive: true, participantCount: 2, category: '音乐' });

    const result = await listVoiceRooms({ category: '音乐' }, makeContext('u1'));
    expect(result.rooms.length).toBe(1);
    expect(result.rooms[0].title).toBe('音乐房');
  });
});
