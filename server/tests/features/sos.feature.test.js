/**
 * Feature tests for /api/v1/sos endpoints.
 */

jest.mock('firebase-admin', () => ({
  initializeApp: jest.fn(), credential: { cert: jest.fn() },
  auth:      jest.fn(() => ({ verifyIdToken: jest.fn().mockResolvedValue({ uid: 'test-uid' }), getUser: jest.fn() })),
  messaging: jest.fn(() => ({ send: jest.fn().mockResolvedValue('msg-id') })),
  database:  jest.fn(() => ({ ref: jest.fn().mockReturnValue({ set: jest.fn(), get: jest.fn() }) })),
}));
jest.mock('../../src/config/database.config', () => ({ query: jest.fn(), connect: jest.fn() }));
jest.mock('../../src/config/firebase.config', () => ({}));
jest.mock('../../src/services/sos.service');
jest.mock('../../src/services/socket.service', () => ({
  emitAlert:    jest.fn(),
  emitSosAlert: jest.fn(),
}));
jest.mock('../../src/services/notification.service', () => ({
  sendRawNotification: jest.fn(), sendEventAlert: jest.fn(),
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

const request    = require('supertest');
const app        = require('../../src/app');
const sosService = require('../../src/services/sos.service');

const ELDERLY_ID   = 'elderly-uuid';
const CAREGIVER_ID = 'cg-uuid';
const SOS_ID       = 'sos-uuid';

const fakeSos = {
  id: SOS_ID, elderly_id: ELDERLY_ID, caregiver_id: CAREGIVER_ID,
  status: 'pending', source: 'manual',
  elderly_name: 'Ali Hassan', created_at: new Date().toISOString(),
};

beforeEach(() => jest.clearAllMocks());

// ── POST /sos (elder triggers SOS) ───────────────────────────────────────────

describe('POST /api/v1/sos', () => {
  it('returns 201 when SOS is created', async () => {
    sosService.createSos.mockResolvedValue(fakeSos);

    const res = await request(app).post('/api/v1/sos')
      .send({ elderly_id: ELDERLY_ID, source: 'manual' });

    expect(res.status).toBe(201);
    expect(res.body.data.sos_id).toBe(SOS_ID);
  });

  it('returns 400 when elderly_id is missing', async () => {
    const res = await request(app).post('/api/v1/sos').send({});

    expect(res.status).toBe(400);
  });

  it('defaults source to "manual" when omitted', async () => {
    sosService.createSos.mockResolvedValue(fakeSos);

    await request(app).post('/api/v1/sos').send({ elderly_id: ELDERLY_ID });

    expect(sosService.createSos).toHaveBeenCalledWith(ELDERLY_ID, 'manual');
  });

  it('passes custom source to the service', async () => {
    const autoSos = { ...fakeSos, source: 'auto_fall' };
    sosService.createSos.mockResolvedValue(autoSos);

    const res = await request(app).post('/api/v1/sos')
      .send({ elderly_id: ELDERLY_ID, source: 'auto_fall' });

    expect(res.status).toBe(201);
    expect(sosService.createSos).toHaveBeenCalledWith(ELDERLY_ID, 'auto_fall');
  });

  it('FCM notification is non-blocking — responds 201 even if FCM is pending', async () => {
    sosService.createSos.mockResolvedValue(fakeSos);

    const res = await request(app).post('/api/v1/sos')
      .send({ elderly_id: ELDERLY_ID });

    // Response arrives before FCM resolves
    expect(res.status).toBe(201);
    // Let the micro-task queue drain
    await new Promise((r) => setImmediate(r));
  });
});

// ── PUT /sos/:sosId/acknowledge ───────────────────────────────────────────────

describe('PUT /api/v1/sos/:sosId/acknowledge', () => {
  it('returns 200 with acknowledged SOS', async () => {
    const acknowledged = { ...fakeSos, status: 'acknowledged' };
    sosService.acknowledgeSos.mockResolvedValue(acknowledged);

    const res = await request(app)
      .put(`/api/v1/sos/${SOS_ID}/acknowledge`);

    expect(res.status).toBe(200);
    expect(res.body.data.sos.status).toBe('acknowledged');
  });

  it('passes the authenticated caregiver_id to the service', async () => {
    const acknowledged = { ...fakeSos, status: 'acknowledged' };
    sosService.acknowledgeSos.mockResolvedValue(acknowledged);

    await request(app).put(`/api/v1/sos/${SOS_ID}/acknowledge`);

    expect(sosService.acknowledgeSos).toHaveBeenCalledWith(SOS_ID, CAREGIVER_ID);
  });

  it('returns 404 when SOS not found or not owned by caregiver', async () => {
    sosService.acknowledgeSos.mockRejectedValue(
      Object.assign(new Error('SOS not found or not authorized'), { statusCode: 404 })
    );

    const res = await request(app).put(`/api/v1/sos/unknown/acknowledge`);

    expect(res.status).toBe(404);
  });
});

// ── GET /sos/history ──────────────────────────────────────────────────────────

describe('GET /api/v1/sos/history', () => {
  it('returns 200 with history and count', async () => {
    sosService.getSosHistory.mockResolvedValue([fakeSos]);

    const res = await request(app).get('/api/v1/sos/history');

    expect(res.status).toBe(200);
    expect(res.body.data.history).toHaveLength(1);
    expect(res.body.data.count).toBe(1);
  });

  it('passes limit and offset query params to the service', async () => {
    sosService.getSosHistory.mockResolvedValue([]);

    await request(app).get('/api/v1/sos/history').query({ limit: '5', offset: '10' });

    expect(sosService.getSosHistory).toHaveBeenCalledWith(CAREGIVER_ID, 5, 10);
  });

  it('uses authenticated caregiver id', async () => {
    sosService.getSosHistory.mockResolvedValue([]);

    await request(app).get('/api/v1/sos/history');

    expect(sosService.getSosHistory).toHaveBeenCalledWith(
      CAREGIVER_ID, expect.any(Number), expect.any(Number)
    );
  });

  it('returns empty array when caregiver has no SOS history', async () => {
    sosService.getSosHistory.mockResolvedValue([]);

    const res = await request(app).get('/api/v1/sos/history');

    expect(res.status).toBe(200);
    expect(res.body.data.history).toHaveLength(0);
    expect(res.body.data.count).toBe(0);
  });
});
