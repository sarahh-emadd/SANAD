/**
 * Unit tests for qr.service.js
 * DB pool, QRCode package, and firebase.config are mocked.
 */

jest.mock('../../src/config/database.config', () => ({
  query:   jest.fn(),
  connect: jest.fn(),
}));
jest.mock('qrcode', () => ({
  toDataURL: jest.fn().mockResolvedValue('data:image/png;base64,mockQRImage'),
}));
jest.mock('../../src/config/firebase.config', () => ({
  messaging: { send: jest.fn().mockResolvedValue('msg-id') },
}));
jest.mock('../../src/utils/logger', () => ({
  info: jest.fn(), error: jest.fn(), warn: jest.fn(),
  http: jest.fn(), success: jest.fn(), debug: jest.fn(),
}));

const pool      = require('../../src/config/database.config');
const qrService = require('../../src/services/qr.service');

const ELDERLY_ID  = 'elderly-uuid';
const TOKEN       = 'a'.repeat(64);   // 64-char hex string
const MANUAL_CODE = '123456';

const mockClient = { query: jest.fn(), release: jest.fn() };

beforeEach(() => {
  jest.clearAllMocks();
  pool.connect.mockResolvedValue(mockClient);
  mockClient.query.mockResolvedValue({ rows: [], rowCount: 0 });
});

// ── generateManualCode ────────────────────────────────────────────────────

describe('QRService.generateManualCode', () => {
  it('returns a 6-digit string', () => {
    const code = qrService.generateManualCode();
    expect(code).toMatch(/^\d{6}$/);
  });

  it('is in range 100000–999999', () => {
    for (let i = 0; i < 20; i++) {
      const n = parseInt(qrService.generateManualCode());
      expect(n).toBeGreaterThanOrEqual(100000);
      expect(n).toBeLessThanOrEqual(999999);
    }
  });
});

// ── generateQRCodeData ────────────────────────────────────────────────────

describe('QRService.generateQRCodeData', () => {
  it('returns a JSON string with type SANAD_ELDERLY_PAIRING', () => {
    const data = qrService.generateQRCodeData(TOKEN, MANUAL_CODE);
    const parsed = JSON.parse(data);

    expect(parsed.type).toBe('SANAD_ELDERLY_PAIRING');
    expect(parsed.token).toBe(TOKEN);
    expect(parsed.manualCode).toBe(MANUAL_CODE);
    expect(parsed.version).toBe('1.0');
  });
});

// ── verifyTokenValidity ───────────────────────────────────────────────────

describe('QRService.verifyTokenValidity', () => {
  it('returns true when a valid active token exists', async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ id: 'qt-uuid' }] });
    expect(await qrService.verifyTokenValidity(TOKEN)).toBe(true);
  });

  it('returns false when token is expired or not found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    expect(await qrService.verifyTokenValidity('badtoken')).toBe(false);
  });
});

// ── verifyManualCodeValidity ──────────────────────────────────────────────

describe('QRService.verifyManualCodeValidity', () => {
  it('returns true for a valid active code', async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ id: 'qt-uuid' }] });
    expect(await qrService.verifyManualCodeValidity(MANUAL_CODE)).toBe(true);
  });

  it('returns false for expired or unknown code', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    expect(await qrService.verifyManualCodeValidity('000000')).toBe(false);
  });
});

// ── generateQRToken ───────────────────────────────────────────────────────

describe('QRService.generateQRToken', () => {
  it('runs transaction, generates QR image, returns full token data', async () => {
    const fakeQRRow = {
      id: 'qt-uuid', elderly_id: ELDERLY_ID,
      token: TOKEN, manual_code: MANUAL_CODE,
      expires_at: new Date(),
    };
    mockClient.query
      .mockResolvedValueOnce({ rows: [] })            // BEGIN
      .mockResolvedValueOnce({ rows: [] })            // REVOKE old tokens
      .mockResolvedValueOnce({ rows: [fakeQRRow] })   // INSERT new token
      .mockResolvedValueOnce({ rows: [] });            // COMMIT

    const result = await qrService.generateQRToken(ELDERLY_ID);

    expect(result.qrToken).toEqual(fakeQRRow);
    expect(result.manualCode).toBe(MANUAL_CODE);
    expect(result.qrCodeImage).toContain('data:image/png');
    expect(mockClient.release).toHaveBeenCalled();
  });

  it('rolls back and rethrows on failure', async () => {
    mockClient.query
      .mockResolvedValueOnce({ rows: [] })                  // BEGIN
      .mockRejectedValueOnce(new Error('constraint error')); // INSERT fails

    await expect(qrService.generateQRToken(ELDERLY_ID)).rejects.toThrow('constraint error');
    expect(mockClient.release).toHaveBeenCalled();
  });
});

// ── disconnectElderlyDevice ───────────────────────────────────────────────

describe('QRService.disconnectElderlyDevice', () => {
  it('runs a transaction and returns success message', async () => {
    mockClient.query
      .mockResolvedValueOnce({ rows: [] })  // BEGIN
      .mockResolvedValueOnce({ rows: [] })  // UPDATE elderly
      .mockResolvedValueOnce({ rows: [] })  // UPDATE elderly_connections
      .mockResolvedValueOnce({ rows: [] })  // UPDATE qr_tokens
      .mockResolvedValueOnce({ rows: [] }); // COMMIT

    const result = await qrService.disconnectElderlyDevice(ELDERLY_ID);
    expect(result.message).toMatch(/disconnected/i);
    expect(mockClient.release).toHaveBeenCalled();
  });
});

// ── revokeExpiredTokens ───────────────────────────────────────────────────

describe('QRService.revokeExpiredTokens', () => {
  it('returns count of revoked tokens', async () => {
    pool.query.mockResolvedValueOnce({
      rows: [{ elderly_id: ELDERLY_ID, token: TOKEN }],
      rowCount: 1,
    });

    const result = await qrService.revokeExpiredTokens();
    expect(result.revokedCount).toBe(1);
  });

  it('returns zero when no tokens to revoke', async () => {
    pool.query.mockResolvedValueOnce({ rows: [], rowCount: 0 });
    const result = await qrService.revokeExpiredTokens();
    expect(result.revokedCount).toBe(0);
  });
});
