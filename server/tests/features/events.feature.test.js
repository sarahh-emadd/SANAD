/**
 * Feature tests for /api/v1/events endpoints.
 */

jest.mock('firebase-admin', () => ({
  initializeApp: jest.fn(), credential: { cert: jest.fn() },
  auth:      jest.fn(() => ({ verifyIdToken: jest.fn().mockResolvedValue({ uid: 'test-uid' }), getUser: jest.fn() })),
  messaging: jest.fn(() => ({ send: jest.fn().mockResolvedValue('msg-id') })),
  database:  jest.fn(() => ({ ref: jest.fn().mockReturnValue({ set: jest.fn(), get: jest.fn() }) })),
}));
jest.mock('../../src/config/database.config', () => ({ query: jest.fn(), connect: jest.fn() }));
jest.mock('../../src/config/firebase.config', () => ({}));
jest.mock('../../src/services/events.service');
jest.mock('../../src/services/sos.service');
jest.mock('../../src/services/socket.service', () => ({
  emitAlert:    jest.fn(),
  emitSosAlert: jest.fn(),
}));
jest.mock('../../src/services/notification.service', () => ({
  sendRawNotification: jest.fn(), sendEventAlert: jest.fn().mockResolvedValue({ success: true }),
  sendSosAlert: jest.fn().mockResolvedValue({}),
  sendGeofenceAlert: jest.fn(), sendBatteryAlert: jest.fn(), sendSosEscalation: jest.fn(),
}));
jest.mock('../../src/middlewares/firebase-auth.middleware', () => ({
  verifyFirebaseToken: (req, _res, next) => {
    req.user = { uid: 'test-uid', id: 'cg-uuid' };
    next();
  },
}));
jest.mock('../../src/utils/logger', () => ({
  info: jest.fn(), error: jest.fn(), warn: jest.fn(),
  http: jest.fn(), success: jest.fn(), debug: jest.fn(),
}));

const request       = require('supertest');
const app           = require('../../src/app');
const eventsService = require('../../src/services/events.service');
const sosService    = require('../../src/services/sos.service');
const pool          = require('../../src/config/database.config');

const ELDERLY_ID   = 'elderly-uuid';
const CAREGIVER_ID = 'cg-uuid';
const EVENT_ID     = 'event-uuid';

const fakeEvent = {
  id: EVENT_ID, elderly_id: ELDERLY_ID,
  event_type: 'fall', confidence: 0.95,
  snapshot_url: null, created_at: new Date().toISOString(),
};

beforeEach(() => jest.clearAllMocks());

// ── POST /events (Python AI detection) ───────────────────────────────────

describe('POST /api/v1/events', () => {
  const validPayload = {
    elderly_id: ELDERLY_ID, event_type: 'fall', confidence: 0.95,
  };

  it('returns 201 when event is created', async () => {
    eventsService.createEvent.mockResolvedValue(fakeEvent);
    // caregiver_id lookup
    pool.query.mockResolvedValueOnce({ rows: [{ caregiver_id: CAREGIVER_ID }] });
    eventsService.markAlertSent.mockResolvedValue();

    const res = await request(app).post('/api/v1/events').send(validPayload);

    expect(res.status).toBe(201);
    expect(res.body.data.event.event_type).toBe('fall');
  });

  it('returns 400 when elderly_id is missing', async () => {
    const res = await request(app).post('/api/v1/events')
      .send({ event_type: 'fall', confidence: 0.9 });
    expect(res.status).toBe(400);
  });

  it('returns 400 for an invalid event_type', async () => {
    const res = await request(app).post('/api/v1/events')
      .send({ elderly_id: ELDERLY_ID, event_type: 'unknown', confidence: 0.9 });
    expect(res.status).toBe(400);
  });

  it('accepts all valid event types', async () => {
    const validTypes = ['fall', 'inactivity', 'sleeping', 'night_restlessness'];

    for (const event_type of validTypes) {
      const e = { ...fakeEvent, event_type };
      eventsService.createEvent.mockResolvedValue(e);
      pool.query.mockResolvedValueOnce({ rows: [] }); // no caregiver found → skip FCM

      const res = await request(app).post('/api/v1/events')
        .send({ elderly_id: ELDERLY_ID, event_type, confidence: 0.8 });

      expect(res.status).toBe(201);
    }
  });

  it('triggers auto-SOS pipeline when event_type is fall', async () => {
    eventsService.createEvent.mockResolvedValue({ ...fakeEvent, event_type: 'fall' });
    pool.query.mockResolvedValueOnce({ rows: [{ caregiver_id: CAREGIVER_ID }] });
    eventsService.markAlertSent.mockResolvedValue();
    sosService.createSos.mockResolvedValue({ id: 'sos-uuid', elderly_name: 'Ali' });

    const res = await request(app).post('/api/v1/events')
      .send({ elderly_id: ELDERLY_ID, event_type: 'fall', confidence: 0.95 });

    expect(res.status).toBe(201);
    // auto-SOS is non-blocking — verify it was called after a tick
    await new Promise((r) => setImmediate(r));
    expect(sosService.createSos).toHaveBeenCalledWith(ELDERLY_ID, 'auto_fall');
  });
});

// ── GET /events/:elderlyId ────────────────────────────────────────────────

describe('GET /api/v1/events/:elderlyId', () => {
  it('returns 200 with events and count', async () => {
    eventsService.getEventsByElderly.mockResolvedValue([fakeEvent]);

    const res = await request(app).get(`/api/v1/events/${ELDERLY_ID}`);

    expect(res.status).toBe(200);
    expect(res.body.data.events).toHaveLength(1);
    expect(res.body.data.count).toBe(1);
  });

  it('passes limit and offset query params', async () => {
    eventsService.getEventsByElderly.mockResolvedValue([]);

    await request(app).get(`/api/v1/events/${ELDERLY_ID}`).query({ limit: '5', offset: '10' });

    expect(eventsService.getEventsByElderly).toHaveBeenCalledWith(ELDERLY_ID, 5, 10);
  });
});

// ── GET /events/unverified ────────────────────────────────────────────────

describe('GET /api/v1/events/unverified', () => {
  it('returns 200 with unverified events', async () => {
    eventsService.getUnverifiedEvents.mockResolvedValue([fakeEvent]);

    const res = await request(app).get('/api/v1/events/unverified');

    expect(res.status).toBe(200);
    expect(res.body.data.events).toHaveLength(1);
  });
});

// ── PUT /events/:eventId/verify ───────────────────────────────────────────

describe('PUT /api/v1/events/:eventId/verify', () => {
  it('returns 200 when event is verified', async () => {
    const verified = { ...fakeEvent, verified: true };
    eventsService.verifyEvent.mockResolvedValue(verified);

    const res = await request(app)
      .put(`/api/v1/events/${EVENT_ID}/verify`)
      .send({ is_false_positive: false });

    expect(res.status).toBe(200);
    expect(res.body.data.event.verified).toBe(true);
  });

  it('marks event as false positive when flag is set', async () => {
    const fp = { ...fakeEvent, verified: true, is_false_positive: true };
    eventsService.verifyEvent.mockResolvedValue(fp);

    const res = await request(app)
      .put(`/api/v1/events/${EVENT_ID}/verify`)
      .send({ is_false_positive: true });

    expect(res.status).toBe(200);
    expect(res.body.data.event.is_false_positive).toBe(true);
  });
});

// ── GET /events/detail/:eventId ───────────────────────────────────────────

describe('GET /api/v1/events/detail/:eventId', () => {
  it('returns 200 with event detail', async () => {
    eventsService.getEventById.mockResolvedValue(fakeEvent);

    const res = await request(app).get(`/api/v1/events/detail/${EVENT_ID}`);

    expect(res.status).toBe(200);
    expect(res.body.data.event.id).toBe(EVENT_ID);
  });
});

// ── GET /events/today-stats/:elderlyId ────────────────────────────────────

describe('GET /api/v1/events/today-stats/:elderlyId', () => {
  it('returns 200 with stats and activityLevel', async () => {
    eventsService.getTodayStats.mockResolvedValue({
      fall: 1, inactivity: 0, sleeping: 0, night_restlessness: 0, total: 1,
    });

    const res = await request(app).get(`/api/v1/events/today-stats/${ELDERLY_ID}`);

    expect(res.status).toBe(200);
    expect(res.body.data.activityLevel).toBe('Alert 🚨');
  });

  it('returns "Normal" activity level when no events today', async () => {
    eventsService.getTodayStats.mockResolvedValue({
      fall: 0, inactivity: 0, sleeping: 0, night_restlessness: 0, total: 0,
    });

    const res = await request(app).get(`/api/v1/events/today-stats/${ELDERLY_ID}`);

    expect(res.body.data.activityLevel).toBe('Normal');
  });
});

// ── GET /events/notifications ─────────────────────────────────────────────

describe('GET /api/v1/events/notifications', () => {
  it('returns 200 with combined event + SOS notifications', async () => {
    pool.query.mockResolvedValueOnce({
      rows: [
        { type: 'event', id: EVENT_ID, event_type: 'fall', elderly_name: 'Ali' },
        { type: 'sos',   id: 'sos-1',  event_type: 'sos',  elderly_name: 'Ali' },
      ],
    });

    const res = await request(app).get('/api/v1/events/notifications');

    expect(res.status).toBe(200);
    expect(res.body.data.notifications).toHaveLength(2);
  });
});
