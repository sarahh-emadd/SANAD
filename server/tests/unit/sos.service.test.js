/**
 * Unit tests for sos.service.js
 * DB pool mocked — no real connections.
 */

jest.mock('../../src/config/database.config', () => ({ query: jest.fn() }));
jest.mock('../../src/utils/logger', () => ({
  info: jest.fn(), error: jest.fn(), warn: jest.fn(),
  http: jest.fn(), success: jest.fn(), debug: jest.fn(),
}));

const pool       = require('../../src/config/database.config');
const sosService = require('../../src/services/sos.service');

const ELDERLY_ID   = 'elderly-uuid';
const CAREGIVER_ID = 'cg-uuid';
const SOS_ID       = 'sos-uuid';

beforeEach(() => jest.clearAllMocks());

// ── createSos ─────────────────────────────────────────────────────────────

describe('SosService.createSos', () => {
  it('fetches caregiver_id, inserts SOS, returns merged row', async () => {
    const elderlyRow = {
      id: ELDERLY_ID, caregiver_id: CAREGIVER_ID, elderly_name: 'Ali Hassan',
    };
    const sosRow = {
      id: SOS_ID, elderly_id: ELDERLY_ID, caregiver_id: CAREGIVER_ID,
      status: 'pending', source: 'manual',
    };

    pool.query
      .mockResolvedValueOnce({ rows: [elderlyRow] })  // SELECT elderly
      .mockResolvedValueOnce({ rows: [sosRow] });      // INSERT sos_request

    const result = await sosService.createSos(ELDERLY_ID, 'manual');

    expect(result.id).toBe(SOS_ID);
    expect(result.caregiver_id).toBe(CAREGIVER_ID);
    expect(result.elderly_name).toBe('Ali Hassan');
  });

  it('defaults source to "manual" for unknown source values', async () => {
    const elderlyRow = { id: ELDERLY_ID, caregiver_id: CAREGIVER_ID, elderly_name: 'Ali' };
    const sosRow     = { id: SOS_ID, source: 'manual' };
    pool.query
      .mockResolvedValueOnce({ rows: [elderlyRow] })
      .mockResolvedValueOnce({ rows: [sosRow] });

    const result = await sosService.createSos(ELDERLY_ID, 'invalid_source');
    // The service validates and defaults to 'manual'
    expect(pool.query.mock.calls[1][1]).toContain('manual');
  });

  it('accepts "auto_fall" source', async () => {
    const elderlyRow = { id: ELDERLY_ID, caregiver_id: CAREGIVER_ID, elderly_name: 'Ali' };
    const sosRow     = { id: SOS_ID, source: 'auto_fall' };
    pool.query
      .mockResolvedValueOnce({ rows: [elderlyRow] })
      .mockResolvedValueOnce({ rows: [sosRow] });

    await sosService.createSos(ELDERLY_ID, 'auto_fall');
    expect(pool.query.mock.calls[1][1]).toContain('auto_fall');
  });

  it('throws when elderly is not found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    await expect(sosService.createSos('unknown', 'manual'))
      .rejects.toThrow(`Elderly not found: unknown`);
  });
});

// ── acknowledgeSos ────────────────────────────────────────────────────────

describe('SosService.acknowledgeSos', () => {
  it('updates and returns acknowledged SOS row', async () => {
    const sosRow = { id: SOS_ID, status: 'acknowledged' };
    pool.query.mockResolvedValueOnce({ rows: [sosRow] });

    const result = await sosService.acknowledgeSos(SOS_ID, CAREGIVER_ID);
    expect(result.status).toBe('acknowledged');
    expect(pool.query.mock.calls[0][1]).toEqual([SOS_ID, CAREGIVER_ID]);
  });

  it('throws when SOS not found or not owned by this caregiver', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    await expect(sosService.acknowledgeSos('unknown', CAREGIVER_ID))
      .rejects.toThrow('SOS not found or not authorized');
  });
});

// ── getSosHistory ─────────────────────────────────────────────────────────

describe('SosService.getSosHistory', () => {
  it('returns paginated SOS history', async () => {
    const fakeHistory = [
      { id: SOS_ID, status: 'acknowledged', elderly_name: 'Ali Hassan' },
    ];
    pool.query.mockResolvedValueOnce({ rows: fakeHistory });

    const result = await sosService.getSosHistory(CAREGIVER_ID, 10, 0);
    expect(result).toEqual(fakeHistory);
    expect(pool.query.mock.calls[0][1]).toEqual([CAREGIVER_ID, 10, 0]);
  });

  it('uses default limit=20 and offset=0', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    await sosService.getSosHistory(CAREGIVER_ID);
    expect(pool.query.mock.calls[0][1]).toEqual([CAREGIVER_ID, 20, 0]);
  });
});
