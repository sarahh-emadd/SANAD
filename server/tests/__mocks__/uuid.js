// CJS shim for uuid v13 (ESM-only package).
// Jest's moduleNameMapper points here so the test environment never touches
// the ESM dist. Node >=14.17 provides crypto.randomUUID() natively.
module.exports = {
  v4: () => require('crypto').randomUUID(),
  v1: () => require('crypto').randomUUID(),
  v3: () => require('crypto').randomUUID(),
  v5: () => require('crypto').randomUUID(),
};
