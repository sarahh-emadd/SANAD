/**
 * Feature tests for /api/v1/qr endpoints.
 *
 * All four routes are PUBLIC (no Firebase auth required).
 * qr.service is auto-mocked; we control return values per test.
 */

jest.mock('firebase-admin', () => ({
  initializeApp: jest.fn(), credential: { cert: jest.fn() },
  auth:      jest.fn(() => ({ verifyIdToken: jest.fn().mockResolvedValue({ uid: 'test-uid' }), getUser: jest.fn() })),
  messaging: jest.fn(() => ({ send: jest.fn().mockResolvedValue('msg-id') })),
  database:  jest.fn(() => ({ ref: jest.fn().mockReturnValue({ set: jest.fn(), get: jest.fn() }) })),
}));
jest.mock('../../src/config/database.config', () => ({ query: jest.fn(), connect: jest.fn() }));
jest.mock('../../src/config/firebase.config', () => ({}));
jest.mock('../../src/services/qr.service');
jest.mock('../../src/services/notification.service', () => ({
  sendRawNotification: jest.fn(), sendEventAlert: jest.fn(), sendSosAlert: jest.fn(),
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

const request   = require('supertest');
const app       = require('../../src/app');
const qrService = require('../../src/services/qr.service');

const ELDERLY_ID  = 'elderly-uuid';
const VALID_TOKEN = 'a'.repeat(64);   // 64-char hex string
const MANUAL_CODE = '123456';

const fakeConnectionResult = {
  connection: { id: 'conn-uuid', elderly_id: ELDERLY_ID, connected_at: new Date().toISOString() },
  elderly: {
    id: ELDERLY_ID, name: 'Ali Hassan',
    first_name: 'Ali', last_name: 'Hassan',
    caregiver_id: 'cg-uuid', is_connected: true,
  },
  message: 'Device connected successfully',
};

beforeEach(() => jest.clearAllMocks());

// ── POST /qr/connect ──────────────────────────────────────────────────────────

describe('POST /api/v1/qr/connect', () => {
  it('returns 200 with connection data when token is valid', async () => {
    qrService.connectElderlyDevice.mockResolvedValue(fakeConnectionResult);

    const res = await request(app).post('/api/v1/qr/connect')
      .send({ token: VALID_TOKEN, deviceToken: 'fcm-token-xyz' });

    expect(res.status).toBe(200);
    expect(res.body.data.elderly.id).toBe(ELDERLY_ID);
  });

  it('returns 400 when token is missing', async () => {
    const res = await request(app).post('/api/v1/qr/connect')
      .send({ deviceToken: 'fcm-token-xyz' });

    expect(res.status).toBe(400);
  });

  it('returns 400 when deviceToken is missing', async () => {
    const res = await request(app).post('/api/v1/qr/connect')
      .send({ token: VALID_TOKEN });

    expect(res.status).toBe(400);
  });

  it('returns 400 for a token shorter than 64 characters', async () => {
    const res = await request(app).post('/api/v1/qr/connect')
      .send({ token: 'abc123', deviceToken: 'fcm-token-xyz' });

    expect(res.status).toBe(400);
  });

  it('returns 400 when the token is expired or invalid (service throws)', async () => {
    qrService.connectElderlyDevice.mockRejectedValue(
      Object.assign(new Error('Invalid or expired QR code'), { statusCode: 400 })
    );

    const res = await request(app).post('/api/v1/qr/connect')
      .send({ token: VALID_TOKEN, deviceToken: 'fcm-token-xyz' });

    expect(res.status).toBe(400);
  });

  it('calls service with correct arguments', async () => {
    qrService.connectElderlyDevice.mockResolvedValue(fakeConnectionResult);

    await request(app).post('/api/v1/qr/connect')
      .send({ token: VALID_TOKEN, deviceToken: 'fcm-device-token' });

    expect(qrService.connectElderlyDevice).toHaveBeenCalledWith(VALID_TOKEN, 'fcm-device-token');
  });
});

// ── POST /qr/connect-manual ───────────────────────────────────────────────────

describe('POST /api/v1/qr/connect-manual', () => {
  it('returns 200 with connection data when code is valid', async () => {
    qrService.connectWithManualCode.mockResolvedValue(fakeConnectionResult);

    const res = await request(app).post('/api/v1/qr/connect-manual')
      .send({ manualCode: MANUAL_CODE, deviceToken: 'fcm-token-xyz' });

    expect(res.status).toBe(200);
    expect(res.body.data.elderly.id).toBe(ELDERLY_ID);
  });

  it('returns 400 when manualCode is missing', async () => {
    const res = await request(app).post('/api/v1/qr/connect-manual')
      .send({ deviceToken: 'fcm-token-xyz' });

    expect(res.status).toBe(400);
  });

  it('returns 400 when deviceToken is missing', async () => {
    const res = await request(app).post('/api/v1/qr/connect-manual')
      .send({ manualCode: MANUAL_CODE });

    expect(res.status).toBe(400);
  });

  it('returns 400 for a non-numeric manual code', async () => {
    const res = await request(app).post('/api/v1/qr/connect-manual')
      .send({ manualCode: 'ABCDEF', deviceToken: 'fcm-token-xyz' });

    expect(res.status).toBe(400);
  });

  it('returns 400 for a code that is not exactly 6 digits', async () => {
    const res = await request(app).post('/api/v1/qr/connect-manual')
      .send({ manualCode: '12345', deviceToken: 'fcm-token-xyz' }); // only 5 digits

    expect(res.status).toBe(400);
  });

  it('returns 400 when code is expired (service throws)', async () => {
    qrService.connectWithManualCode.mockRejectedValue(
      Object.assign(new Error('Invalid or expired manual code'), { statusCode: 400 })
    );

    const res = await request(app).post('/api/v1/qr/connect-manual')
      .send({ manualCode: MANUAL_CODE, deviceToken: 'fcm-token-xyz' });

    expect(res.status).toBe(400);
  });

  it('calls service with correct arguments', async () => {
    qrService.connectWithManualCode.mockResolvedValue(fakeConnectionResult);

    await request(app).post('/api/v1/qr/connect-manual')
      .send({ manualCode: MANUAL_CODE, deviceToken: 'fcm-device-token' });

    expect(qrService.connectWithManualCode).toHaveBeenCalledWith(MANUAL_CODE, 'fcm-device-token');
  });
});

// ── POST /qr/verify ───────────────────────────────────────────────────────────

describe('POST /api/v1/qr/verify', () => {
  it('returns 200 with valid:true for a valid token', async () => {
    qrService.verifyTokenValidity.mockResolvedValue(true);

    const res = await request(app).post('/api/v1/qr/verify')
      .send({ token: VALID_TOKEN });

    expect(res.status).toBe(200);
    expect(res.body.data.valid).toBe(true);
  });

  it('returns 400 when token is missing', async () => {
    const res = await request(app).post('/api/v1/qr/verify').send({});

    expect(res.status).toBe(400);
  });

  it('returns 400 for a malformed token (not 64 hex chars)', async () => {
    const res = await request(app).post('/api/v1/qr/verify')
      .send({ token: 'not-a-valid-token' });

    expect(res.status).toBe(400);
  });

  it('returns 400 when token is expired or not found', async () => {
    qrService.verifyTokenValidity.mockResolvedValue(false);

    const res = await request(app).post('/api/v1/qr/verify')
      .send({ token: VALID_TOKEN });

    expect(res.status).toBe(400);
  });
});

// ── POST /qr/verify-manual ────────────────────────────────────────────────────

describe('POST /api/v1/qr/verify-manual', () => {
  it('returns 200 with valid:true for a valid manual code', async () => {
    qrService.verifyManualCodeValidity.mockResolvedValue(true);

    const res = await request(app).post('/api/v1/qr/verify-manual')
      .send({ manualCode: MANUAL_CODE });

    expect(res.status).toBe(200);
    expect(res.body.data.valid).toBe(true);
  });

  it('returns 400 when manualCode is missing', async () => {
    const res = await request(app).post('/api/v1/qr/verify-manual').send({});

    expect(res.status).toBe(400);
  });

  it('returns 400 for a non-numeric manual code', async () => {
    const res = await request(app).post('/api/v1/qr/verify-manual')
      .send({ manualCode: 'ABCDEF' });

    expect(res.status).toBe(400);
  });

  it('returns 400 when code is expired or not found', async () => {
    qrService.verifyManualCodeValidity.mockResolvedValue(false);

    const res = await request(app).post('/api/v1/qr/verify-manual')
      .send({ manualCode: MANUAL_CODE });

    expect(res.status).toBe(400);
  });
});
