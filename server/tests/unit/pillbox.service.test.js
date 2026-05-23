/**
 * Unit tests for pillbox.service.js
 * DB pool is fully mocked — no real database or Firebase needed.
 */

jest.mock('../../src/config/database.config', () => ({
  query: jest.fn(),
}));

jest.mock('../../src/utils/logger', () => ({
  info:    jest.fn(),
  error:   jest.fn(),
  warn:    jest.fn(),
  success: jest.fn(),
  debug:   jest.fn(),
  http:    jest.fn(),
}));

const pool    = require('../../src/config/database.config');
const service = require('../../src/services/pillbox.service');

const ELDERLY_ID  = 'test-elderly-uuid';
const SLOT_ID     = 'test-slot-uuid';
const SCHEDULE_ID = 'test-schedule-uuid';
const DEVICE_MAC  = 'AA:BB:CC:DD:EE:FF';

beforeEach(() => jest.clearAllMocks());

// ── SLOTS ──────────────────────────────────────────────────────────────────

describe('PillboxService.getSlots', () => {
  it('auto-creates 3 slot rows then returns them with schedules', async () => {
    const fakeSlots = [
      { id: 's1', slot_number: 1, medication_name: '', schedules: [] },
      { id: 's2', slot_number: 2, medication_name: '', schedules: [] },
      { id: 's3', slot_number: 3, medication_name: '', schedules: [] },
    ];

    // 3 INSERT ON CONFLICT DO NOTHING calls, then 1 SELECT
    pool.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: fakeSlots });

    const result = await service.getSlots(ELDERLY_ID);

    expect(pool.query).toHaveBeenCalledTimes(4);
    expect(result).toEqual(fakeSlots);
    expect(result).toHaveLength(3);
  });
});

describe('PillboxService.updateSlot', () => {
  it('upserts a slot and returns the updated row', async () => {
    const fakeSlot = {
      id: SLOT_ID, slot_number: 1,
      medication_name: 'Aspirin 100mg', notes: null, is_active: true,
    };
    pool.query.mockResolvedValueOnce({ rows: [fakeSlot] });

    const result = await service.updateSlot(ELDERLY_ID, 1, {
      medication_name: 'Aspirin 100mg',
      notes: null,
      is_active: true,
    });

    expect(result).toEqual(fakeSlot);
    expect(pool.query.mock.calls[0][1]).toContain('Aspirin 100mg');
  });
});

// ── SCHEDULES ─────────────────────────────────────────────────────────────

describe('PillboxService.addSchedule', () => {
  it('inserts a new schedule and returns it', async () => {
    const fakeSchedule = {
      id: SCHEDULE_ID, slot_id: SLOT_ID,
      scheduled_time: '08:00', label: 'After Breakfast', is_active: true,
    };
    pool.query.mockResolvedValueOnce({ rows: [fakeSchedule] });

    const result = await service.addSchedule(SLOT_ID, ELDERLY_ID, '08:00', 'After Breakfast');

    expect(result).toEqual(fakeSchedule);
    expect(pool.query.mock.calls[0][1]).toEqual([SLOT_ID, ELDERLY_ID, '08:00', 'After Breakfast']);
  });

  it('passes null label when label is omitted', async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ id: SCHEDULE_ID }] });

    await service.addSchedule(SLOT_ID, ELDERLY_ID, '20:00', undefined);

    expect(pool.query.mock.calls[0][1][3]).toBeNull();
  });
});

describe('PillboxService.updateSchedule', () => {
  it('updates and returns the modified schedule', async () => {
    const fakeSchedule = {
      id: SCHEDULE_ID, slot_id: SLOT_ID,
      scheduled_time: '09:00', label: 'Before Bed', is_active: true,
    };
    pool.query.mockResolvedValueOnce({ rows: [fakeSchedule] });

    const result = await service.updateSchedule(SCHEDULE_ID, {
      time: '09:00', label: 'Before Bed',
    });

    expect(result).toEqual(fakeSchedule);
  });

  it('throws "Schedule not found" when the row does not exist', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    await expect(
      service.updateSchedule('nonexistent-id', { time: '09:00' })
    ).rejects.toThrow('Schedule not found');
  });
});

describe('PillboxService.deleteSchedule', () => {
  it('executes the soft-delete query with the schedule id', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    await service.deleteSchedule(SCHEDULE_ID);

    expect(pool.query).toHaveBeenCalledTimes(1);
    expect(pool.query.mock.calls[0][1]).toEqual([SCHEDULE_ID]);
  });
});

// ── TODAY SCHEDULE ─────────────────────────────────────────────────────────

describe('PillboxService.getTodaySchedule', () => {
  it('returns today\'s schedule rows merged with log status', async () => {
    const fakeRows = [
      {
        schedule_id: SCHEDULE_ID, slot_id: SLOT_ID, slot_number: 1,
        medication_name: 'Aspirin', scheduled_time: '08:00',
        label: 'Morning', log_id: null, dose_status: null,
      },
      {
        schedule_id: 'sc2', slot_id: SLOT_ID, slot_number: 1,
        medication_name: 'Aspirin', scheduled_time: '20:00',
        label: 'Evening', log_id: 'l1', dose_status: 'taken',
      },
    ];
    pool.query.mockResolvedValueOnce({ rows: fakeRows });

    const result = await service.getTodaySchedule(ELDERLY_ID);

    expect(result).toEqual(fakeRows);
    expect(pool.query.mock.calls[0][1]).toEqual([ELDERLY_ID]);
  });
});

// ── LOGS ──────────────────────────────────────────────────────────────────

describe('PillboxService.upsertLog', () => {
  it('returns the inserted log on first dose event', async () => {
    const fakeLog = {
      id: 'log-uuid', schedule_id: SCHEDULE_ID, slot_id: SLOT_ID,
      elderly_id: ELDERLY_ID, status: 'taken',
    };
    pool.query.mockResolvedValueOnce({ rows: [fakeLog] });

    const result = await service.upsertLog(
      SCHEDULE_ID, SLOT_ID, ELDERLY_ID, 'taken', new Date(),
    );

    expect(result).toEqual(fakeLog);
    expect(pool.query).toHaveBeenCalledTimes(1);
  });

  it('falls back to UPDATE when INSERT hits ON CONFLICT DO NOTHING', async () => {
    const fakeLog = { id: 'log-uuid', status: 'missed' };
    pool.query
      .mockResolvedValueOnce({ rows: [] })     // INSERT returns nothing (conflict)
      .mockResolvedValueOnce({ rows: [fakeLog] }); // UPDATE fallback

    const result = await service.upsertLog(
      SCHEDULE_ID, SLOT_ID, ELDERLY_ID, 'missed', new Date(),
    );

    expect(pool.query).toHaveBeenCalledTimes(2);
    expect(result).toEqual(fakeLog);
  });

  it('sets taken_at to NOW for taken status', async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ id: 'log-uuid', status: 'taken' }] });

    await service.upsertLog(SCHEDULE_ID, SLOT_ID, ELDERLY_ID, 'taken', new Date());

    const insertParams = pool.query.mock.calls[0][1];
    // taken_at is the 6th parameter — should be a Date object
    expect(insertParams[5]).toBeInstanceOf(Date);
  });

  it('sets taken_at to null for missed status', async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ id: 'log-uuid', status: 'missed' }] });

    await service.upsertLog(SCHEDULE_ID, SLOT_ID, ELDERLY_ID, 'missed', new Date());

    const insertParams = pool.query.mock.calls[0][1];
    expect(insertParams[5]).toBeNull();
  });
});

describe('PillboxService.markNotified', () => {
  it('runs the UPDATE with the given log id', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    await service.markNotified('log-uuid');

    expect(pool.query.mock.calls[0][1]).toEqual(['log-uuid']);
  });
});

describe('PillboxService.getLogs', () => {
  it('returns paginated dose history with medication details', async () => {
    const fakeLogs = [
      { id: 'l1', status: 'taken', medication_name: 'Aspirin', slot_number: 1 },
      { id: 'l2', status: 'missed', medication_name: 'Metformin', slot_number: 2 },
    ];
    pool.query.mockResolvedValueOnce({ rows: fakeLogs });

    const result = await service.getLogs(ELDERLY_ID, 10, 0);

    expect(result).toEqual(fakeLogs);
    expect(pool.query.mock.calls[0][1]).toEqual([ELDERLY_ID, 10, 0]);
  });

  it('uses default limit=30 and offset=0', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    await service.getLogs(ELDERLY_ID);

    expect(pool.query.mock.calls[0][1]).toEqual([ELDERLY_ID, 30, 0]);
  });
});

// ── DEVICES ───────────────────────────────────────────────────────────────

describe('PillboxService.registerDevice', () => {
  it('upserts and returns the device row', async () => {
    const fakeDevice = {
      id: 'dev-uuid', elderly_id: ELDERLY_ID,
      device_mac: DEVICE_MAC, firmware_version: '1.0.0', is_online: true,
    };
    pool.query.mockResolvedValueOnce({ rows: [fakeDevice] });

    const result = await service.registerDevice(ELDERLY_ID, DEVICE_MAC, '1.0.0');

    expect(result).toEqual(fakeDevice);
    expect(pool.query.mock.calls[0][1]).toContain(DEVICE_MAC);
  });

  it('passes null firmware_version when omitted', async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ id: 'dev-uuid' }] });

    await service.registerDevice(ELDERLY_ID, DEVICE_MAC);

    expect(pool.query.mock.calls[0][1][2]).toBeNull();
  });
});

describe('PillboxService.getElderlyByMac', () => {
  it('returns device + elderly info when device is registered', async () => {
    const fakeRow = {
      elderly_id: ELDERLY_ID, device_mac: DEVICE_MAC, elderly_name: 'Ali Hassan',
    };
    pool.query.mockResolvedValueOnce({ rows: [fakeRow] });

    const result = await service.getElderlyByMac(DEVICE_MAC);

    expect(result).toEqual(fakeRow);
    expect(pool.query.mock.calls[0][1]).toEqual([DEVICE_MAC]);
  });

  it('returns null when the MAC is not registered', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const result = await service.getElderlyByMac('00:00:00:00:00:00');

    expect(result).toBeNull();
  });
});

describe('PillboxService.getCaregiverFcm', () => {
  it('returns caregiver row with fcm_token when linked', async () => {
    const fakeRow = {
      caregiver_id: 'cg-uuid', fcm_token: 'fcm-test-token',
      elderly_name: 'Ali Hassan',
    };
    pool.query.mockResolvedValueOnce({ rows: [fakeRow] });

    const result = await service.getCaregiverFcm(ELDERLY_ID);

    expect(result).toEqual(fakeRow);
    expect(pool.query.mock.calls[0][1]).toEqual([ELDERLY_ID]);
  });

  it('returns null when elderly has no linked caregiver', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const result = await service.getCaregiverFcm(ELDERLY_ID);

    expect(result).toBeNull();
  });
});
