/**
 * Unit tests for events.service.js
 * DB pool and minioService are mocked.
 */

jest.mock('../../src/config/database.config', () => ({ query: jest.fn() }));
jest.mock('../../src/services/minio.service', () => ({
  uploadSnapshot: jest.fn(),
  deleteFile:     jest.fn(),
}));
jest.mock('../../src/utils/logger', () => ({
  info: jest.fn(), error: jest.fn(), warn: jest.fn(),
  http: jest.fn(), success: jest.fn(), debug: jest.fn(),
}));

const pool          = require('../../src/config/database.config');
const minioService  = require('../../src/services/minio.service');
const eventsService = require('../../src/services/events.service');

const ELDERLY_ID = 'elderly-uuid';
const CAREGIVER_ID = 'cg-uuid';
const EVENT_ID   = 'event-uuid';

const fakeEvent = {
  id: EVENT_ID, elderly_id: ELDERLY_ID,
  event_type: 'fall', confidence: 0.95,
  snapshot_url: 'http://minio/snapshot.jpg',
  created_at: new Date().toISOString(),
};

beforeEach(() => jest.clearAllMocks());

// ── createEvent ───────────────────────────────────────────────────────────

describe('EventsService.createEvent', () => {
  it('uploads snapshot to MinIO and saves event to DB', async () => {
    minioService.uploadSnapshot.mockResolvedValueOnce('http://minio/snapshot.jpg');
    pool.query.mockResolvedValueOnce({ rows: [fakeEvent] });

    const result = await eventsService.createEvent(ELDERLY_ID, {
      event_type:       'fall',
      confidence:       0.95,
      snapshot_base64:  'base64encodedimage==',
    });

    expect(minioService.uploadSnapshot).toHaveBeenCalled();
    expect(result).toEqual(fakeEvent);
  });

  it('saves event without snapshot when snapshot_base64 is missing', async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ ...fakeEvent, snapshot_url: null }] });

    const result = await eventsService.createEvent(ELDERLY_ID, {
      event_type: 'inactivity', confidence: 0.7,
    });

    expect(minioService.uploadSnapshot).not.toHaveBeenCalled();
    expect(result.event_type).toBe('inactivity');
  });

  it('continues without snapshot when MinIO upload fails', async () => {
    minioService.uploadSnapshot.mockRejectedValueOnce(new Error('MinIO error'));
    pool.query.mockResolvedValueOnce({ rows: [{ ...fakeEvent, snapshot_url: null }] });

    const result = await eventsService.createEvent(ELDERLY_ID, {
      event_type: 'fall', confidence: 0.9, snapshot_base64: 'img==',
    });

    expect(result).toBeDefined();
  });
});

// ── getEventsByElderly ────────────────────────────────────────────────────

describe('EventsService.getEventsByElderly', () => {
  it('returns paginated event list', async () => {
    pool.query.mockResolvedValueOnce({ rows: [fakeEvent] });

    const result = await eventsService.getEventsByElderly(ELDERLY_ID, 10, 0);
    expect(result).toEqual([fakeEvent]);
    expect(pool.query.mock.calls[0][1]).toEqual([ELDERLY_ID, 10, 0]);
  });
});

// ── getUnverifiedEvents ───────────────────────────────────────────────────

describe('EventsService.getUnverifiedEvents', () => {
  it('returns only unverified events for the caregiver', async () => {
    pool.query.mockResolvedValueOnce({ rows: [fakeEvent] });

    const result = await eventsService.getUnverifiedEvents(CAREGIVER_ID);
    expect(result).toEqual([fakeEvent]);
    expect(pool.query.mock.calls[0][1]).toContain(CAREGIVER_ID);
  });
});

// ── verifyEvent ───────────────────────────────────────────────────────────

describe('EventsService.verifyEvent', () => {
  it('marks event as verified and returns updated row', async () => {
    const verified = { ...fakeEvent, verified: true, is_false_positive: false };
    pool.query.mockResolvedValueOnce({ rows: [verified] });

    const result = await eventsService.verifyEvent(EVENT_ID, CAREGIVER_ID, false);
    expect(result.verified).toBe(true);
  });

  it('marks event as false positive', async () => {
    const fp = { ...fakeEvent, verified: true, is_false_positive: true };
    pool.query.mockResolvedValueOnce({ rows: [fp] });

    const result = await eventsService.verifyEvent(EVENT_ID, CAREGIVER_ID, true);
    expect(result.is_false_positive).toBe(true);
  });

  it('throws 404 when event not found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    await expect(eventsService.verifyEvent('unknown', CAREGIVER_ID)).rejects.toThrow('Event not found');
  });
});

// ── markAlertSent ─────────────────────────────────────────────────────────

describe('EventsService.markAlertSent', () => {
  it('executes the UPDATE query with the event id', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    await eventsService.markAlertSent(EVENT_ID);
    expect(pool.query.mock.calls[0][1]).toEqual([EVENT_ID]);
  });
});

// ── getEventById ──────────────────────────────────────────────────────────

describe('EventsService.getEventById', () => {
  it('returns the event row when found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [fakeEvent] });
    const result = await eventsService.getEventById(EVENT_ID);
    expect(result).toEqual(fakeEvent);
  });

  it('throws 404 when event not found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    await expect(eventsService.getEventById('unknown')).rejects.toThrow('Event not found');
  });
});

// ── getTodayStats ─────────────────────────────────────────────────────────

describe('EventsService.getTodayStats', () => {
  it('aggregates event counts by type', async () => {
    pool.query.mockResolvedValueOnce({
      rows: [
        { event_type: 'fall',       count: '2' },
        { event_type: 'inactivity', count: '1' },
      ],
    });

    const stats = await eventsService.getTodayStats(ELDERLY_ID);

    expect(stats.fall).toBe(2);
    expect(stats.inactivity).toBe(1);
    expect(stats.sleeping).toBe(0);
    expect(stats.total).toBe(3);
  });

  it('returns all-zero stats when no events today', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    const stats = await eventsService.getTodayStats(ELDERLY_ID);
    expect(stats.total).toBe(0);
    expect(stats.fall).toBe(0);
  });
});
