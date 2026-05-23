/**
 * Feature tests for the pillbox API endpoints.
 * Services and Firebase are fully mocked — no database or real auth required.
 *
 * Covers all 10 routes defined in pillbox.routes.js:
 *   Caregiver (Firebase auth bypassed): getSlots, updateSlot, addSchedule,
 *     updateSchedule, deleteSchedule, getLogs, getTodaySchedule
 *   ESP32 (no auth): registerDevice, getDeviceSchedule, reportDose
 */

// Mock all heavyweight dependencies before the app is imported.
// Order matters: jest.mock() calls are hoisted but must appear before require().

// firebase-admin: prevents initializeApp() crash and stubs auth/messaging
jest.mock('firebase-admin', () => ({
  initializeApp: jest.fn(),
  credential:    { cert: jest.fn() },
  auth:      jest.fn(() => ({
    verifyIdToken: jest.fn().mockResolvedValue({ uid: 'test-uid', email: 'test@test.com' }),
    getUser:       jest.fn().mockResolvedValue({ uid: 'test-uid' }),
  })),
  messaging: jest.fn(() => ({
    send: jest.fn().mockResolvedValue('projects/test/messages/mock-id'),
  })),
  database:  jest.fn(() => ({
    ref: jest.fn().mockReturnValue({ set: jest.fn(), get: jest.fn() }),
  })),
}));

jest.mock('../../src/config/database.config', () => ({ query: jest.fn() }));
jest.mock('../../src/config/firebase.config', () => ({}));
jest.mock('../../src/services/pillbox.service');
jest.mock('../../src/services/notification.service', () => ({
  sendRawNotification:  jest.fn().mockResolvedValue({}),
  sendEventAlert:       jest.fn().mockResolvedValue({}),
  sendSosAlert:         jest.fn().mockResolvedValue({}),
  sendGeofenceAlert:    jest.fn().mockResolvedValue({}),
  sendBatteryAlert:     jest.fn().mockResolvedValue({}),
  sendSosEscalation:    jest.fn().mockResolvedValue({}),
}));
jest.mock('../../src/middlewares/firebase-auth.middleware', () => ({
  verifyFirebaseToken: (req, _res, next) => {
    req.user = { uid: 'test-uid', id: 'test-caregiver-id' };
    next();
  },
}));
// Logger: mock all six methods so services that call logger.success/debug don't throw
jest.mock('../../src/utils/logger', () => ({
  info:    jest.fn(),
  error:   jest.fn(),
  warn:    jest.fn(),
  http:    jest.fn(),
  success: jest.fn(),
  debug:   jest.fn(),
}));

const request        = require('supertest');
const app            = require('../../src/app');
const pillboxService = require('../../src/services/pillbox.service');

const ELDERLY_ID  = 'test-elderly-uuid';
const SLOT_ID     = 'test-slot-uuid';
const SCHEDULE_ID = 'test-schedule-uuid';
const DEVICE_MAC  = 'AA:BB:CC:DD:EE:FF';

beforeEach(() => jest.clearAllMocks());

// ── GET /api/v1/pillbox/slots/:elderlyId ──────────────────────────────────

describe('GET /api/v1/pillbox/slots/:elderlyId', () => {
  it('returns 200 with 3 slots', async () => {
    const fakeSlots = [
      { id: 's1', slot_number: 1, medication_name: 'Aspirin', schedules: [] },
      { id: 's2', slot_number: 2, medication_name: 'Metformin', schedules: [] },
      { id: 's3', slot_number: 3, medication_name: '', schedules: [] },
    ];
    pillboxService.getSlots.mockResolvedValue(fakeSlots);

    const res = await request(app).get(`/api/v1/pillbox/slots/${ELDERLY_ID}`);

    expect(res.status).toBe(200);
    expect(res.body.data.slots).toHaveLength(3);
    expect(pillboxService.getSlots).toHaveBeenCalledWith(ELDERLY_ID);
  });
});

// ── PUT /api/v1/pillbox/slots/:elderlyId/:slotNumber ──────────────────────

describe('PUT /api/v1/pillbox/slots/:elderlyId/:slotNumber', () => {
  it('returns 200 with updated slot', async () => {
    const fakeSlot = {
      id: SLOT_ID, slot_number: 1, medication_name: 'Aspirin 100mg', is_active: true,
    };
    pillboxService.updateSlot.mockResolvedValue(fakeSlot);

    const res = await request(app)
      .put(`/api/v1/pillbox/slots/${ELDERLY_ID}/1`)
      .send({ medication_name: 'Aspirin 100mg', is_active: true });

    expect(res.status).toBe(200);
    expect(res.body.data.slot.medication_name).toBe('Aspirin 100mg');
    expect(pillboxService.updateSlot).toHaveBeenCalledWith(ELDERLY_ID, 1, expect.any(Object));
  });

  it('returns 400 when slotNumber is not 1, 2, or 3', async () => {
    const res = await request(app)
      .put(`/api/v1/pillbox/slots/${ELDERLY_ID}/5`)
      .send({ medication_name: 'Test' });

    expect(res.status).toBe(400);
    expect(pillboxService.updateSlot).not.toHaveBeenCalled();
  });

  it('returns 400 for slot number 0', async () => {
    const res = await request(app)
      .put(`/api/v1/pillbox/slots/${ELDERLY_ID}/0`)
      .send({ medication_name: 'Test' });

    expect(res.status).toBe(400);
  });
});

// ── POST /api/v1/pillbox/schedules ────────────────────────────────────────

describe('POST /api/v1/pillbox/schedules', () => {
  const validBody = {
    slot_id:    SLOT_ID,
    elderly_id: ELDERLY_ID,
    time:       '08:00',
    label:      'After Breakfast',
  };

  it('returns 201 with created schedule', async () => {
    const fakeSchedule = {
      id: SCHEDULE_ID, slot_id: SLOT_ID,
      scheduled_time: '08:00', label: 'After Breakfast', is_active: true,
    };
    pillboxService.addSchedule.mockResolvedValue(fakeSchedule);

    const res = await request(app)
      .post('/api/v1/pillbox/schedules')
      .send(validBody);

    expect(res.status).toBe(201);
    expect(res.body.data.schedule.scheduled_time).toBe('08:00');
    expect(pillboxService.addSchedule).toHaveBeenCalledWith(
      SLOT_ID, ELDERLY_ID, '08:00', 'After Breakfast',
    );
  });

  it('returns 400 when slot_id is missing', async () => {
    const res = await request(app)
      .post('/api/v1/pillbox/schedules')
      .send({ elderly_id: ELDERLY_ID, time: '08:00' });

    expect(res.status).toBe(400);
    expect(pillboxService.addSchedule).not.toHaveBeenCalled();
  });

  it('returns 400 when time is missing', async () => {
    const res = await request(app)
      .post('/api/v1/pillbox/schedules')
      .send({ slot_id: SLOT_ID, elderly_id: ELDERLY_ID });

    expect(res.status).toBe(400);
  });
});

// ── PUT /api/v1/pillbox/schedules/:scheduleId ─────────────────────────────

describe('PUT /api/v1/pillbox/schedules/:scheduleId', () => {
  it('returns 200 with updated schedule', async () => {
    const fakeSchedule = {
      id: SCHEDULE_ID, scheduled_time: '09:00', label: 'Before Bed', is_active: true,
    };
    pillboxService.updateSchedule.mockResolvedValue(fakeSchedule);

    const res = await request(app)
      .put(`/api/v1/pillbox/schedules/${SCHEDULE_ID}`)
      .send({ time: '09:00', label: 'Before Bed' });

    expect(res.status).toBe(200);
    expect(res.body.data.schedule.scheduled_time).toBe('09:00');
  });

  it('returns 500 when schedule is not found (service throws)', async () => {
    pillboxService.updateSchedule.mockRejectedValue(new Error('Schedule not found'));

    const res = await request(app)
      .put(`/api/v1/pillbox/schedules/nonexistent`)
      .send({ time: '09:00' });

    expect(res.status).toBeGreaterThanOrEqual(400);
  });
});

// ── DELETE /api/v1/pillbox/schedules/:scheduleId ──────────────────────────

describe('DELETE /api/v1/pillbox/schedules/:scheduleId', () => {
  it('returns 200 on successful soft-delete', async () => {
    pillboxService.deleteSchedule.mockResolvedValue(undefined);

    const res = await request(app).delete(`/api/v1/pillbox/schedules/${SCHEDULE_ID}`);

    expect(res.status).toBe(200);
    expect(pillboxService.deleteSchedule).toHaveBeenCalledWith(SCHEDULE_ID);
  });
});

// ── GET /api/v1/pillbox/logs/:elderlyId ──────────────────────────────────

describe('GET /api/v1/pillbox/logs/:elderlyId', () => {
  it('returns 200 with dose logs and count', async () => {
    const fakeLogs = [
      { id: 'l1', status: 'taken',  medication_name: 'Aspirin',   slot_number: 1 },
      { id: 'l2', status: 'missed', medication_name: 'Metformin', slot_number: 2 },
    ];
    pillboxService.getLogs.mockResolvedValue(fakeLogs);

    const res = await request(app).get(`/api/v1/pillbox/logs/${ELDERLY_ID}`);

    expect(res.status).toBe(200);
    expect(res.body.data.logs).toHaveLength(2);
    expect(res.body.data.count).toBe(2);
  });

  it('passes limit and offset query params to service', async () => {
    pillboxService.getLogs.mockResolvedValue([]);

    await request(app)
      .get(`/api/v1/pillbox/logs/${ELDERLY_ID}`)
      .query({ limit: '5', offset: '10' });

    expect(pillboxService.getLogs).toHaveBeenCalledWith(ELDERLY_ID, 5, 10);
  });
});

// ── GET /api/v1/pillbox/today/:elderlyId ─────────────────────────────────

describe('GET /api/v1/pillbox/today/:elderlyId', () => {
  it('returns 200 with today\'s schedule', async () => {
    const fakeSchedule = [
      {
        schedule_id: SCHEDULE_ID, slot_number: 1,
        medication_name: 'Aspirin', scheduled_time: '08:00',
        dose_status: 'taken',
      },
    ];
    pillboxService.getTodaySchedule.mockResolvedValue(fakeSchedule);

    const res = await request(app).get(`/api/v1/pillbox/today/${ELDERLY_ID}`);

    expect(res.status).toBe(200);
    expect(res.body.data.schedule).toHaveLength(1);
    expect(res.body.data.schedule[0].dose_status).toBe('taken');
  });
});

// ── POST /api/v1/pillbox/device/register ─────────────────────────────────

describe('POST /api/v1/pillbox/device/register', () => {
  it('returns 201 when ESP32 registers successfully', async () => {
    const fakeDevice = {
      id: 'dev-uuid', elderly_id: ELDERLY_ID,
      device_mac: DEVICE_MAC, firmware_version: '1.0.0', is_online: true,
    };
    pillboxService.registerDevice.mockResolvedValue(fakeDevice);

    const res = await request(app)
      .post('/api/v1/pillbox/device/register')
      .send({ elderly_id: ELDERLY_ID, device_mac: DEVICE_MAC, firmware_version: '1.0.0' });

    expect(res.status).toBe(201);
    expect(res.body.data.device.device_mac).toBe(DEVICE_MAC);
    expect(res.body.data.device.is_online).toBe(true);
  });

  it('returns 400 when elderly_id is missing', async () => {
    const res = await request(app)
      .post('/api/v1/pillbox/device/register')
      .send({ device_mac: DEVICE_MAC });

    expect(res.status).toBe(400);
    expect(pillboxService.registerDevice).not.toHaveBeenCalled();
  });

  it('returns 400 when device_mac is missing', async () => {
    const res = await request(app)
      .post('/api/v1/pillbox/device/register')
      .send({ elderly_id: ELDERLY_ID });

    expect(res.status).toBe(400);
  });
});

// ── GET /api/v1/pillbox/device/schedule ──────────────────────────────────

describe('GET /api/v1/pillbox/device/schedule', () => {
  it('returns 200 with schedule when elderly_id is provided directly', async () => {
    const fakeSchedule = [
      { schedule_id: SCHEDULE_ID, slot_number: 1, scheduled_time: '08:00' },
    ];
    pillboxService.getTodaySchedule.mockResolvedValue(fakeSchedule);

    const res = await request(app)
      .get('/api/v1/pillbox/device/schedule')
      .query({ elderly_id: ELDERLY_ID });

    expect(res.status).toBe(200);
    expect(res.body.data.schedule).toHaveLength(1);
  });

  it('resolves elderly_id from device_mac when elderly_id is not given', async () => {
    const fakeDevice = { elderly_id: ELDERLY_ID, device_mac: DEVICE_MAC };
    pillboxService.getElderlyByMac.mockResolvedValue(fakeDevice);
    pillboxService.getTodaySchedule.mockResolvedValue([]);

    const res = await request(app)
      .get('/api/v1/pillbox/device/schedule')
      .query({ device_mac: DEVICE_MAC });

    expect(res.status).toBe(200);
    expect(pillboxService.getElderlyByMac).toHaveBeenCalledWith(DEVICE_MAC);
    expect(pillboxService.getTodaySchedule).toHaveBeenCalledWith(ELDERLY_ID);
  });

  it('returns 404 when device_mac is not registered', async () => {
    pillboxService.getElderlyByMac.mockResolvedValue(null);

    const res = await request(app)
      .get('/api/v1/pillbox/device/schedule')
      .query({ device_mac: '00:00:00:00:00:00' });

    expect(res.status).toBe(404);
  });

  it('returns 400 when neither elderly_id nor device_mac is provided', async () => {
    const res = await request(app).get('/api/v1/pillbox/device/schedule');

    expect(res.status).toBe(400);
  });
});

// ── POST /api/v1/pillbox/device/report ───────────────────────────────────

describe('POST /api/v1/pillbox/device/report', () => {
  const validPayload = {
    device_mac:   DEVICE_MAC,
    elderly_id:   ELDERLY_ID,
    schedule_id:  SCHEDULE_ID,
    slot_id:      SLOT_ID,
    slot_number:  1,
    scheduled_at: new Date().toISOString(),
    status:       'taken',
  };

  it('returns 201 when a taken dose is reported', async () => {
    const fakeLog = { id: 'log-uuid', status: 'taken' };
    pillboxService.upsertLog.mockResolvedValue(fakeLog);
    pillboxService.getCaregiverFcm.mockResolvedValue(null);

    const res = await request(app)
      .post('/api/v1/pillbox/device/report')
      .send(validPayload);

    expect(res.status).toBe(201);
    expect(res.body.data.log.status).toBe('taken');
    expect(pillboxService.upsertLog).toHaveBeenCalled();
  });

  it('returns 201 when a missed dose is reported', async () => {
    const fakeLog = { id: 'log-uuid', status: 'missed' };
    pillboxService.upsertLog.mockResolvedValue(fakeLog);
    pillboxService.getCaregiverFcm.mockResolvedValue(null);

    const res = await request(app)
      .post('/api/v1/pillbox/device/report')
      .send({ ...validPayload, status: 'missed' });

    expect(res.status).toBe(201);
    expect(res.body.data.log.status).toBe('missed');
  });

  it('returns 400 for an invalid status value', async () => {
    const res = await request(app)
      .post('/api/v1/pillbox/device/report')
      .send({ ...validPayload, status: 'pending' });

    expect(res.status).toBe(400);
    expect(pillboxService.upsertLog).not.toHaveBeenCalled();
  });

  it('returns 400 when required fields are missing', async () => {
    const res = await request(app)
      .post('/api/v1/pillbox/device/report')
      .send({ elderly_id: ELDERLY_ID, status: 'taken' }); // missing slot_id, scheduled_at

    expect(res.status).toBe(400);
  });

  it('sends FCM notification to caregiver when fcm_token is present', async () => {
    const notificationService = require('../../src/services/notification.service');
    const fakeLog = { id: 'log-uuid', status: 'taken' };
    pillboxService.upsertLog.mockResolvedValue(fakeLog);
    pillboxService.getCaregiverFcm.mockResolvedValue({
      caregiver_id: 'cg-uuid',
      fcm_token: 'test-fcm-token',
      elderly_name: 'Ali Hassan',
    });
    pillboxService.markNotified.mockResolvedValue(undefined);

    await request(app)
      .post('/api/v1/pillbox/device/report')
      .send(validPayload);

    // FCM is non-blocking — wait a tick for the promise chain
    await new Promise((r) => setImmediate(r));

    expect(notificationService.sendRawNotification).toHaveBeenCalledWith(
      'test-fcm-token',
      expect.objectContaining({ title: expect.stringContaining('Taken') }),
    );
    expect(pillboxService.markNotified).toHaveBeenCalledWith('log-uuid');
  });
});
