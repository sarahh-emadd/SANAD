/**
 * Feature tests for /api/v1/auth endpoints.
 */

jest.mock('firebase-admin', () => ({
  initializeApp: jest.fn(), credential: { cert: jest.fn() },
  auth:      jest.fn(() => ({ verifyIdToken: jest.fn().mockResolvedValue({ uid: 'test-uid' }), getUser: jest.fn() })),
  messaging: jest.fn(() => ({ send: jest.fn().mockResolvedValue('msg-id') })),
  database:  jest.fn(() => ({ ref: jest.fn().mockReturnValue({ set: jest.fn(), get: jest.fn() }) })),
}));
jest.mock('../../src/config/database.config', () => ({ query: jest.fn(), connect: jest.fn() }));
jest.mock('../../src/config/firebase.config', () => ({}));
jest.mock('../../src/services/auth.service');
jest.mock('../../src/services/notification.service', () => ({
  sendRawNotification: jest.fn(), sendEventAlert: jest.fn(), sendSosAlert: jest.fn(),
  sendGeofenceAlert: jest.fn(), sendBatteryAlert: jest.fn(), sendSosEscalation: jest.fn(),
}));
jest.mock('../../src/middlewares/firebase-auth.middleware', () => ({
  verifyFirebaseToken: (req, _res, next) => {
    req.user      = { uid: 'test-uid', id: 'cg-uuid' };
    req.firebaseUid = 'test-uid';
    next();
  },
}));
jest.mock('../../src/utils/logger', () => ({
  info: jest.fn(), error: jest.fn(), warn: jest.fn(),
  http: jest.fn(), success: jest.fn(), debug: jest.fn(),
}));

const request     = require('supertest');
const app         = require('../../src/app');
const authService = require('../../src/services/auth.service');

const UID   = 'test-uid';
const EMAIL = 'test@sanad.com';
const fakeUser = { id: 'cg-uuid', firebase_uid: UID, email: EMAIL, first_name: 'Ali' };

beforeEach(() => jest.clearAllMocks());

// ── POST /sync ────────────────────────────────────────────────────────────

describe('POST /api/v1/auth/sync', () => {
  const validBody = {
    firebase_uid: UID, email: EMAIL, first_name: 'Ali', last_name: 'Hassan',
  };

  it('returns 201 and creates user when new', async () => {
    authService.verifyFirebaseUser.mockResolvedValue({ uid: UID });
    authService.findByFirebaseUid.mockResolvedValue(null);
    authService.emailExists.mockResolvedValue(false);
    authService.createCaregiver.mockResolvedValue(fakeUser);

    const res = await request(app).post('/api/v1/auth/sync').send(validBody);

    expect(res.status).toBe(201);
    expect(res.body.data.user.email).toBe(EMAIL);
  });

  it('returns 200 when user already exists', async () => {
    authService.verifyFirebaseUser.mockResolvedValue({ uid: UID });
    authService.findByFirebaseUid.mockResolvedValue(fakeUser);

    const res = await request(app).post('/api/v1/auth/sync').send(validBody);

    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/already exists/i);
  });

  it('returns 409 when email is taken by a different Firebase account', async () => {
    authService.verifyFirebaseUser.mockResolvedValue({ uid: UID });
    authService.findByFirebaseUid.mockResolvedValue(null);
    authService.emailExists.mockResolvedValue(true);

    const res = await request(app).post('/api/v1/auth/sync').send(validBody);

    expect(res.status).toBe(409);
  });

  it('returns 400 when firebase_uid is missing', async () => {
    const res = await request(app).post('/api/v1/auth/sync')
      .send({ email: EMAIL, first_name: 'Ali', last_name: 'Hassan' });
    expect(res.status).toBe(400);
  });

  it('returns 400 when first_name is missing', async () => {
    const res = await request(app).post('/api/v1/auth/sync')
      .send({ firebase_uid: UID, email: EMAIL, last_name: 'Hassan' });
    expect(res.status).toBe(400);
  });
});

// ── POST /check-email ─────────────────────────────────────────────────────

describe('POST /api/v1/auth/check-email', () => {
  it('returns exists:true when email is registered', async () => {
    authService.emailExists.mockResolvedValue(true);

    const res = await request(app).post('/api/v1/auth/check-email').send({ email: EMAIL });

    expect(res.status).toBe(200);
    expect(res.body.data.exists).toBe(true);
  });

  it('returns exists:false when email is free', async () => {
    authService.emailExists.mockResolvedValue(false);

    const res = await request(app).post('/api/v1/auth/check-email').send({ email: 'new@test.com' });

    expect(res.status).toBe(200);
    expect(res.body.data.exists).toBe(false);
  });

  it('returns 400 when email field is missing', async () => {
    const res = await request(app).post('/api/v1/auth/check-email').send({});
    expect(res.status).toBe(400);
  });
});

// ── GET /me ───────────────────────────────────────────────────────────────

describe('GET /api/v1/auth/me', () => {
  it('returns 200 with user + stats', async () => {
    authService.getUserStats.mockResolvedValue({ total_elderly: 2, connected_elderly: 1 });

    const res = await request(app).get('/api/v1/auth/me');

    expect(res.status).toBe(200);
    expect(res.body.data.stats.total_elderly).toBe(2);
  });
});

// ── PUT /profile ──────────────────────────────────────────────────────────

describe('PUT /api/v1/auth/profile', () => {
  it('returns 200 with updated profile', async () => {
    const updated = { ...fakeUser, first_name: 'Ahmad' };
    authService.updateProfile.mockResolvedValue(updated);

    const res = await request(app).put('/api/v1/auth/profile')
      .send({ first_name: 'Ahmad' });

    expect(res.status).toBe(200);
    expect(res.body.data.user.first_name).toBe('Ahmad');
  });

  it('returns 400 for an invalid phone number format', async () => {
    const res = await request(app).put('/api/v1/auth/profile')
      .send({ phone: 'not-a-phone!!!' });
    expect(res.status).toBe(400);
  });
});

// ── POST /fcm-token ───────────────────────────────────────────────────────

describe('POST /api/v1/auth/fcm-token', () => {
  it('returns 200 when FCM token is updated', async () => {
    authService.updateFCMToken.mockResolvedValue({});

    const res = await request(app).post('/api/v1/auth/fcm-token')
      .send({ fcm_token: 'new-fcm-token' });

    expect(res.status).toBe(200);
  });

  it('returns 400 when fcm_token is missing', async () => {
    const res = await request(app).post('/api/v1/auth/fcm-token').send({});
    expect(res.status).toBe(400);
  });
});

// ── DELETE /account ───────────────────────────────────────────────────────

describe('DELETE /api/v1/auth/account', () => {
  it('returns 200 on successful soft-delete', async () => {
    authService.deleteAccount.mockResolvedValue({ message: 'Account deleted successfully' });

    const res = await request(app).delete('/api/v1/auth/account');

    expect(res.status).toBe(200);
  });
});
