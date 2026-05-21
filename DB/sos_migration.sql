-- ============================================================
-- Migration: add SOS requests table
-- File: sos_migration.sql
-- Run: psql -U postgres -d graduation_project_db < sos_migration.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS sos_requests (
  id               UUID         DEFAULT gen_random_uuid() PRIMARY KEY,
  elderly_id       UUID         NOT NULL REFERENCES elderly(id)    ON DELETE CASCADE,
  caregiver_id     UUID         NOT NULL REFERENCES caregivers(id) ON DELETE CASCADE,
  status           VARCHAR(20)  NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending', 'acknowledged', 'dismissed')),
  acknowledged_at  TIMESTAMPTZ,
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Index for caregiver history queries
CREATE INDEX IF NOT EXISTS idx_sos_caregiver ON sos_requests(caregiver_id);
-- Index for elderly lookups
CREATE INDEX IF NOT EXISTS idx_sos_elderly   ON sos_requests(elderly_id);
-- Index for pending SOS queries (status filter)
CREATE INDEX IF NOT EXISTS idx_sos_status    ON sos_requests(status) WHERE status = 'pending';

-- Verify
SELECT 'sos_requests table created successfully' AS result;
