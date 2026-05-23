/**
 * Unit tests for auth.service.js
 * DB pool and Firebase auth are mocked — no real connections.
 */

jest.mock('../../src/config/database.config', () => ({
  query:   jest.fn(),
  connect: jest.fn(),
}));
jest.mock('../../src/config/firebase.config', () => ({
  auth: {
    getUser:       jest.fn(),
    verifyIdToken: jest.fn(),
  },
}));
jest.mock('../../src/utils/logger', () => ({
  info: jest.fn(), error: jest.fn(), warn: jest.fn(),
  http: jest.fn(), success: jest.fn(), debug: jest.fn(),
}));

const pool        = require('../../src/config/database.config');
const { auth }    = require('../../src/config/firebase.config');
const authService = require('../../src/services/auth.service');

const UID   = 'firebase-uid-123';
const EMAIL = 'test@sanad.com';

// mockClient for transaction-based methods (deleteAccount)
const mockClient = { query: jest.fn(), release: jest.fn() };

beforeEach(() => {
  jest.clearAllMocks();
  pool.connect.mockResolvedValue(mockClient);
  mockClient.query.mockResolvedValue({ rows: [], rowCount: 0 });
});

// ── createCaregiver ───────────────────────────────────────────────────────

describe('AuthService.createCaregiver', () => {
  it('inserts and returns the new caregiver row', async () => {
    const fakeUser = { id: 'cg-uuid', firebase_uid: UID, email: EMAIL };
    pool.query.mockResolvedValueOnce({ rows: [fakeUser] });

    const result = await authService.createCaregiver({
      firebase_uid: UID, email: EMAIL, first_name: 'Ali', last_name: 'Hassan',
    });

    expect(result).toEqual(fakeUser);
    expect(pool.query.mock.calls[0][1]).toContain(UID);
    expect(pool.query.mock.calls[0][1]).toContain(EMAIL);
  });
});

// ── findByFirebaseUid ─────────────────────────────────────────────────────

describe('AuthService.findByFirebaseUid', () => {
  it('returns the caregiver row when found', async () => {
    const fakeUser = { id: 'cg-uuid', firebase_uid: UID };
    pool.query.mockResolvedValueOnce({ rows: [fakeUser] });

    const result = await authService.findByFirebaseUid(UID);
    expect(result).toEqual(fakeUser);
  });

  it('returns null when no matching user', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const result = await authService.findByFirebaseUid('nonexistent');
    expect(result).toBeNull();
  });
});

// ── findByEmail ───────────────────────────────────────────────────────────

describe('AuthService.findByEmail', () => {
  it('returns caregiver row for existing email', async () => {
    const fakeUser = { id: 'cg-uuid', email: EMAIL };
    pool.query.mockResolvedValueOnce({ rows: [fakeUser] });

    const result = await authService.findByEmail(EMAIL);
    expect(result).toEqual(fakeUser);
  });

  it('returns null for unknown email', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    const result = await authService.findByEmail('nobody@test.com');
    expect(result).toBeNull();
  });
});

// ── emailExists ───────────────────────────────────────────────────────────

describe('AuthService.emailExists', () => {
  it('returns true when email is registered', async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ id: 'cg-uuid' }] });
    expect(await authService.emailExists(EMAIL)).toBe(true);
  });

  it('returns false when email is not registered', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    expect(await authService.emailExists('new@test.com')).toBe(false);
  });
});

// ── updateProfile ─────────────────────────────────────────────────────────

describe('AuthService.updateProfile', () => {
  it('updates and returns the user row', async () => {
    const updated = { id: 'cg-uuid', first_name: 'Updated', email: EMAIL };
    pool.query.mockResolvedValueOnce({ rows: [updated] });

    const result = await authService.updateProfile(UID, { first_name: 'Updated' });
    expect(result).toEqual(updated);
  });

  it('throws 404 when user not found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    await expect(authService.updateProfile('unknown', {})).rejects.toThrow('User not found');
  });
});

// ── updateFCMToken ────────────────────────────────────────────────────────

describe('AuthService.updateFCMToken', () => {
  it('updates and returns the user row', async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ id: 'cg-uuid', email: EMAIL }] });
    const result = await authService.updateFCMToken(UID, 'new-fcm-token');
    expect(result.email).toBe(EMAIL);
  });

  it('throws 404 when user not found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    await expect(authService.updateFCMToken('unknown', 'token')).rejects.toThrow('User not found');
  });
});

// ── getUserStats ──────────────────────────────────────────────────────────

describe('AuthService.getUserStats', () => {
  it('returns parsed integer counts', async () => {
    pool.query.mockResolvedValueOnce({
      rows: [{ total_elderly: '3', connected_elderly: '2' }],
    });

    const stats = await authService.getUserStats('cg-uuid');
    expect(stats.total_elderly).toBe(3);
    expect(stats.connected_elderly).toBe(2);
  });
});

// ── verifyFirebaseUser ────────────────────────────────────────────────────

describe('AuthService.verifyFirebaseUser', () => {
  it('returns Firebase user data when UID is valid', async () => {
    const fakeFirebaseUser = { uid: UID, email: EMAIL };
    auth.getUser.mockResolvedValueOnce(fakeFirebaseUser);

    const result = await authService.verifyFirebaseUser(UID);
    expect(result).toEqual(fakeFirebaseUser);
  });

  it('throws 400 ApiError when Firebase UID is invalid', async () => {
    auth.getUser.mockRejectedValueOnce(new Error('user not found'));
    await expect(authService.verifyFirebaseUser('bad-uid')).rejects.toThrow('Invalid Firebase user');
  });
});

// ── deleteAccount ─────────────────────────────────────────────────────────

describe('AuthService.deleteAccount', () => {
  it('runs a transaction that archives elderly and soft-deletes caregiver', async () => {
    mockClient.query
      .mockResolvedValueOnce({ rows: [] })   // BEGIN
      .mockResolvedValueOnce({ rows: [] })   // UPDATE elderly → archived
      .mockResolvedValueOnce({ rows: [{ email: EMAIL }] }) // UPDATE caregivers → deleted
      .mockResolvedValueOnce({ rows: [] });  // COMMIT

    const result = await authService.deleteAccount(UID, 'cg-uuid');
    expect(result.message).toMatch(/deleted/i);
    expect(mockClient.release).toHaveBeenCalled();
  });
});
