/**
 * Unit tests for elderly.service.js
 * DB pool and qrService are mocked.
 */

jest.mock('../../src/config/database.config', () => ({
  query:   jest.fn(),
  connect: jest.fn(),
}));
jest.mock('../../src/services/qr.service', () => ({
  generateQRToken:       jest.fn(),
  getActiveQRToken:      jest.fn(),
  disconnectElderlyDevice: jest.fn(),
}));
jest.mock('../../src/utils/logger', () => ({
  info: jest.fn(), error: jest.fn(), warn: jest.fn(),
  http: jest.fn(), success: jest.fn(), debug: jest.fn(),
}));

const pool          = require('../../src/config/database.config');
const qrService     = require('../../src/services/qr.service');
const elderlyService = require('../../src/services/elderly.service');

const CG_ID     = 'caregiver-uuid';
const ELDERLY_ID = 'elderly-uuid';

const fakeElderly = {
  id: ELDERLY_ID, caregiver_id: CG_ID,
  first_name: 'Ali', last_name: 'Hassan',
};
const fakeQRData = {
  qrToken: { id: 'qt-uuid' }, qrCodeData: '{}',
  qrCodeImage: 'data:image/png;base64,...',
  manualCode: '123456', expiresAt: new Date(), expiresIn: '5 minutes',
};

// mockClient for transaction-based methods
const mockClient = { query: jest.fn(), release: jest.fn() };

beforeEach(() => {
  jest.clearAllMocks();
  pool.connect.mockResolvedValue(mockClient);
  mockClient.query.mockResolvedValue({ rows: [], rowCount: 0 });
});

// ── createElderly ─────────────────────────────────────────────────────────

describe('ElderlyService.createElderly', () => {
  it('runs a transaction, creates elderly, generates QR, and returns combined result', async () => {
    mockClient.query
      .mockResolvedValueOnce({ rows: [] })            // BEGIN
      .mockResolvedValueOnce({ rows: [fakeElderly] }) // INSERT elderly
      .mockResolvedValueOnce({ rows: [] });            // COMMIT
    qrService.generateQRToken.mockResolvedValueOnce(fakeQRData);

    const result = await elderlyService.createElderly(CG_ID, {
      first_name: 'Ali', last_name: 'Hassan',
      date_of_birth: '1950-01-01',
      emergency_contact_name: 'Sara', emergency_contact_phone: '05550000',
    });

    expect(result.elderly).toEqual(fakeElderly);
    expect(result.qrToken).toBeDefined();
    expect(qrService.generateQRToken).toHaveBeenCalledWith(ELDERLY_ID);
    expect(mockClient.release).toHaveBeenCalled();
  });

  it('rolls back and rethrows on DB error', async () => {
    mockClient.query
      .mockResolvedValueOnce({ rows: [] })                  // BEGIN
      .mockRejectedValueOnce(new Error('DB insert failed')); // INSERT fails

    await expect(
      elderlyService.createElderly(CG_ID, {
        first_name: 'Ali', last_name: 'Hassan',
        date_of_birth: '1950-01-01',
        emergency_contact_name: 'Sara', emergency_contact_phone: '05550000',
      })
    ).rejects.toThrow('DB insert failed');
    expect(mockClient.release).toHaveBeenCalled();
  });
});

// ── getAllByCaregiver ─────────────────────────────────────────────────────

describe('ElderlyService.getAllByCaregiver', () => {
  it('returns all active elderly for the caregiver', async () => {
    const fakeList = [fakeElderly, { ...fakeElderly, id: 'e2', first_name: 'Fatima' }];
    pool.query.mockResolvedValueOnce({ rows: fakeList });

    const result = await elderlyService.getAllByCaregiver(CG_ID);
    expect(result).toEqual(fakeList);
    expect(pool.query.mock.calls[0][1]).toContain(CG_ID);
  });
});

// ── getById ───────────────────────────────────────────────────────────────

describe('ElderlyService.getById', () => {
  it('returns the elderly row when found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [fakeElderly] });
    const result = await elderlyService.getById(ELDERLY_ID, CG_ID);
    expect(result).toEqual(fakeElderly);
  });

  it('throws 404 when elderly not found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    await expect(elderlyService.getById('unknown', CG_ID)).rejects.toThrow('Elderly not found');
  });
});

// ── updateElderly ─────────────────────────────────────────────────────────

describe('ElderlyService.updateElderly', () => {
  it('updates and returns the modified elderly row', async () => {
    const updated = { ...fakeElderly, first_name: 'Ahmad' };
    pool.query.mockResolvedValueOnce({ rows: [updated] });

    const result = await elderlyService.updateElderly(ELDERLY_ID, CG_ID, { first_name: 'Ahmad' });
    expect(result.first_name).toBe('Ahmad');
  });

  it('throws 404 when elderly not found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    await expect(
      elderlyService.updateElderly('unknown', CG_ID, {})
    ).rejects.toThrow('Elderly not found');
  });
});

// ── deleteElderly ─────────────────────────────────────────────────────────

describe('ElderlyService.deleteElderly', () => {
  it('disconnects device, soft-deletes, and returns message', async () => {
    qrService.disconnectElderlyDevice.mockResolvedValueOnce({});
    pool.query.mockResolvedValueOnce({ rows: [fakeElderly] });

    const result = await elderlyService.deleteElderly(ELDERLY_ID, CG_ID);
    expect(qrService.disconnectElderlyDevice).toHaveBeenCalledWith(ELDERLY_ID, 'elderly_deleted');
    expect(result.message).toMatch(/archived/i);
  });

  it('throws 404 when elderly not found', async () => {
    qrService.disconnectElderlyDevice.mockResolvedValueOnce({});
    pool.query.mockResolvedValueOnce({ rows: [] });
    await expect(elderlyService.deleteElderly('unknown', CG_ID)).rejects.toThrow('Elderly not found');
  });
});

// ── updateLastSeen ────────────────────────────────────────────────────────

describe('ElderlyService.updateLastSeen', () => {
  it('returns updated last_seen row', async () => {
    const row = { id: ELDERLY_ID, last_seen: new Date().toISOString() };
    pool.query.mockResolvedValueOnce({ rows: [row] });

    const result = await elderlyService.updateLastSeen(ELDERLY_ID);
    expect(result.last_seen).toBeDefined();
  });

  it('throws 404 when elderly not found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    await expect(elderlyService.updateLastSeen('unknown')).rejects.toThrow('Elderly not found');
  });
});

// ── getConnectionStats ────────────────────────────────────────────────────

describe('ElderlyService.getConnectionStats', () => {
  it('returns stats row from DB', async () => {
    const stats = {
      total_elderly: '2', connected_count: '1',
      disconnected_count: '1', active_last_hour: '1', active_last_day: '2',
    };
    pool.query.mockResolvedValueOnce({ rows: [stats] });

    const result = await elderlyService.getConnectionStats(CG_ID);
    expect(result).toEqual(stats);
  });
});

// ── getElderlyWithQR ──────────────────────────────────────────────────────

describe('ElderlyService.getElderlyWithQR', () => {
  it('returns elderly + active QR when QR exists', async () => {
    pool.query.mockResolvedValueOnce({ rows: [fakeElderly] });
    qrService.getActiveQRToken.mockResolvedValueOnce(fakeQRData);

    const result = await elderlyService.getElderlyWithQR(ELDERLY_ID, CG_ID);
    expect(result.elderly).toEqual(fakeElderly);
    expect(result.needsRegeneration).toBe(false);
  });

  it('sets needsRegeneration=true when no active QR', async () => {
    pool.query.mockResolvedValueOnce({ rows: [fakeElderly] });
    qrService.getActiveQRToken.mockResolvedValueOnce(null);

    const result = await elderlyService.getElderlyWithQR(ELDERLY_ID, CG_ID);
    expect(result.needsRegeneration).toBe(true);
  });
});
