/**
 * Feature tests for /api/v1/elderly endpoints.
 */

jest.mock('firebase-admin', () => ({
  initializeApp: jest.fn(), credential: { cert: jest.fn() },
  auth:      jest.fn(() => ({ verifyIdToken: jest.fn().mockResolvedValue({ uid: 'test-uid' }), getUser: jest.fn() })),
  messaging: jest.fn(() => ({ send: jest.fn().mockResolvedValue('msg-id') })),
  database:  jest.fn(() => ({ ref: jest.fn().mockReturnValue({ set: jest.fn(), get: jest.fn() }) })),
}));
jest.mock('../../src/config/database.config', () => ({ query: jest.fn(), connect: jest.fn() }));
jest.mock('../../src/config/firebase.config', () => ({}));
jest.mock('../../src/services/elderly.service');
jest.mock('../../src/services/qr.service');
jest.mock('../../src/services/notification.service', () => ({
  sendRawNotification: jest.fn(), sendEventAlert: jest.fn(), sendSosAlert: jest.fn(),
  sendGeofenceAlert: jest.fn().mockResolvedValue({}), sendBatteryAlert: jest.fn().mockResolvedValue({}),
  sendSosEscalation: jest.fn(),
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

const request        = require('supertest');
const app            = require('../../src/app');
const elderlyService = require('../../src/services/elderly.service');
const qrService      = require('../../src/services/qr.service');
const pool           = require('../../src/config/database.config');

const CG_ID     = 'cg-uuid';
const ELDERLY_ID = 'elderly-uuid';

const fakeElderly = {
  id: ELDERLY_ID, caregiver_id: CG_ID,
  first_name: 'Ali', last_name: 'Hassan',
  date_of_birth: '1950-01-01',
};
const fakeQRData = {
  qrToken: { id: 'qt-uuid' }, qrCodeImage: 'data:image/png;base64,...',
  manualCode: '123456', expiresAt: new Date().toISOString(), expiresIn: '5 minutes',
};

beforeEach(() => jest.clearAllMocks());

// ── POST /elderly ─────────────────────────────────────────────────────────

describe('POST /api/v1/elderly', () => {
  const validBody = {
    first_name: 'Ali', last_name: 'Hassan', date_of_birth: '1950-01-01',
    emergency_contact_name: 'Sara', emergency_contact_phone: '0551234567',
  };

  it('returns 201 with elderly + QR data', async () => {
    elderlyService.createElderly.mockResolvedValue({ elderly: fakeElderly, ...fakeQRData });

    const res = await request(app).post('/api/v1/elderly').send(validBody);

    expect(res.status).toBe(201);
    expect(elderlyService.createElderly).toHaveBeenCalledWith(CG_ID, expect.objectContaining({
      first_name: 'Ali',
    }));
  });

  it('returns 400 when first_name is missing', async () => {
    const res = await request(app).post('/api/v1/elderly')
      .send({ ...validBody, first_name: '' });
    expect(res.status).toBe(400);
  });

  it('returns 400 when emergency contact is missing', async () => {
    const { emergency_contact_name, ...body } = validBody;
    const res = await request(app).post('/api/v1/elderly').send(body);
    expect(res.status).toBe(400);
  });
});

// ── GET /elderly ──────────────────────────────────────────────────────────

describe('GET /api/v1/elderly', () => {
  it('returns 200 with elderly list and count', async () => {
    elderlyService.getAllByCaregiver.mockResolvedValue([fakeElderly]);

    const res = await request(app).get('/api/v1/elderly');

    expect(res.status).toBe(200);
    expect(res.body.data.elderly).toHaveLength(1);
    expect(res.body.data.count).toBe(1);
  });
});

// ── GET /elderly/stats ────────────────────────────────────────────────────

describe('GET /api/v1/elderly/stats', () => {
  it('returns 200 with connection stats', async () => {
    elderlyService.getConnectionStats.mockResolvedValue({
      total_elderly: '2', connected_count: '1',
    });

    const res = await request(app).get('/api/v1/elderly/stats');

    expect(res.status).toBe(200);
    expect(res.body.data.stats).toBeDefined();
  });
});

// ── GET /elderly/:id ──────────────────────────────────────────────────────

describe('GET /api/v1/elderly/:id', () => {
  it('returns 200 with elderly record', async () => {
    elderlyService.getById.mockResolvedValue(fakeElderly);

    const res = await request(app).get(`/api/v1/elderly/${ELDERLY_ID}`);

    expect(res.status).toBe(200);
    expect(res.body.data.elderly.id).toBe(ELDERLY_ID);
  });
});

// ── PUT /elderly/:id ──────────────────────────────────────────────────────

describe('PUT /api/v1/elderly/:id', () => {
  it('returns 200 with updated elderly', async () => {
    const updated = { ...fakeElderly, first_name: 'Ahmad' };
    elderlyService.updateElderly.mockResolvedValue(updated);

    const res = await request(app).put(`/api/v1/elderly/${ELDERLY_ID}`)
      .send({ first_name: 'Ahmad' });

    expect(res.status).toBe(200);
    expect(res.body.data.elderly.first_name).toBe('Ahmad');
  });

  it('returns 400 when first_name is an empty string', async () => {
    const res = await request(app).put(`/api/v1/elderly/${ELDERLY_ID}`)
      .send({ first_name: '   ' });
    expect(res.status).toBe(400);
  });
});

// ── DELETE /elderly/:id ───────────────────────────────────────────────────

describe('DELETE /api/v1/elderly/:id', () => {
  it('returns 200 on successful archive', async () => {
    elderlyService.deleteElderly.mockResolvedValue({ message: 'Elderly archived successfully' });

    const res = await request(app).delete(`/api/v1/elderly/${ELDERLY_ID}`);

    expect(res.status).toBe(200);
  });
});

// ── POST /elderly/:id/regenerate-qr ──────────────────────────────────────

describe('POST /api/v1/elderly/:id/regenerate-qr', () => {
  it('returns 200 with new QR code data', async () => {
    elderlyService.regenerateQRCode.mockResolvedValue({ elderly: fakeElderly, ...fakeQRData });

    const res = await request(app).post(`/api/v1/elderly/${ELDERLY_ID}/regenerate-qr`);

    expect(res.status).toBe(200);
  });
});

// ── GET /elderly/:id/caregiver-id (no-auth inline route) ─────────────────

describe('GET /api/v1/elderly/:id/caregiver-id', () => {
  it('returns 200 with caregiver_id when found', async () => {
    pool.query.mockResolvedValueOnce({
      rows: [{ caregiver_id: CG_ID, caregiver_name: 'Sara', elderly_name: 'Ali' }],
    });

    const res = await request(app).get(`/api/v1/elderly/${ELDERLY_ID}/caregiver-id`);

    expect(res.status).toBe(200);
    expect(res.body.data.caregiver_id).toBe(CG_ID);
  });

  it('returns 404 when elderly not found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const res = await request(app).get(`/api/v1/elderly/unknown/caregiver-id`);
    expect(res.status).toBe(404);
  });
});

// ── PUT /elderly/:id/location (no-auth inline route) ─────────────────────

describe('PUT /api/v1/elderly/:id/location', () => {
  it('returns 200 when location is pushed', async () => {
    pool.query.mockResolvedValue({ rows: [] });

    const res = await request(app).put(`/api/v1/elderly/${ELDERLY_ID}/location`)
      .send({ latitude: 30.05, longitude: 31.23 });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('returns 400 when latitude is missing', async () => {
    const res = await request(app).put(`/api/v1/elderly/${ELDERLY_ID}/location`)
      .send({ longitude: 31.23 });
    expect(res.status).toBe(400);
  });
});
