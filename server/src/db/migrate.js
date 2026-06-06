const pool   = require('../config/database.config');
const logger = require('../utils/logger');

async function runMigrations() {
  const client = await pool.connect();
  try {

    // ══════════════════════════════════════════════════════════════════════════
    // CORE TABLES  (must exist before any secondary table that references them)
    // ══════════════════════════════════════════════════════════════════════════

    // ── 1. caregivers ─────────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS caregivers (
        id             UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
        firebase_uid   TEXT      UNIQUE NOT NULL,
        email          TEXT      UNIQUE NOT NULL,
        first_name     TEXT,
        last_name      TEXT,
        phone          TEXT,
        photo_url      TEXT,
        email_verified BOOLEAN   DEFAULT false,
        fcm_token      TEXT,
        status         TEXT      DEFAULT 'active',
        created_at     TIMESTAMP DEFAULT NOW(),
        updated_at     TIMESTAMP DEFAULT NOW()
      )
    `);

    // ── 2. elderly ────────────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS elderly (
        id                             UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
        caregiver_id                   UUID      NOT NULL REFERENCES caregivers(id) ON DELETE CASCADE,
        first_name                     TEXT      NOT NULL,
        last_name                      TEXT      NOT NULL,
        date_of_birth                  DATE,
        gender                         TEXT,
        blood_type                     TEXT,
        phone                          TEXT,
        photo_url                      TEXT,
        device_token                   TEXT,
        emergency_contact_name         TEXT,
        emergency_contact_phone        TEXT,
        emergency_contact_relationship TEXT,
        emergency_contact_email        TEXT,
        address                        TEXT,
        city                           TEXT,
        state                          TEXT,
        postal_code                    TEXT,
        country                        TEXT      DEFAULT 'Egypt',
        medical_conditions             TEXT,
        allergies                      TEXT,
        current_medications            TEXT,
        doctor_name                    TEXT,
        doctor_phone                   TEXT,
        hospital_preference            TEXT,
        mobility_level                 TEXT,
        typical_sleep_time             TIME,
        typical_wake_time              TIME,
        is_connected                   BOOLEAN   DEFAULT false,
        last_seen                      TIMESTAMP,
        status                         TEXT      DEFAULT 'active',
        created_at                     TIMESTAMP DEFAULT NOW(),
        updated_at                     TIMESTAMP DEFAULT NOW()
      )
    `);

    // ── 3. qr_tokens ──────────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS qr_tokens (
        id          UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
        elderly_id  UUID      NOT NULL REFERENCES elderly(id) ON DELETE CASCADE,
        token       TEXT      UNIQUE NOT NULL,
        manual_code TEXT,
        expires_at  TIMESTAMP NOT NULL,
        is_active   BOOLEAN   DEFAULT true,
        used_at     TIMESTAMP,
        revoked_at  TIMESTAMP,
        created_at  TIMESTAMP DEFAULT NOW()
      )
    `);

    // ── 4. elderly_connections ────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS elderly_connections (
        id                   UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
        elderly_id           UUID      NOT NULL REFERENCES elderly(id) ON DELETE CASCADE,
        qr_token_id          UUID      REFERENCES qr_tokens(id),
        connected_at         TIMESTAMP DEFAULT NOW(),
        disconnected_at      TIMESTAMP,
        disconnection_reason TEXT
      )
    `);

    // ── 5. sos_requests ───────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS sos_requests (
        id              UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
        elderly_id      UUID      NOT NULL REFERENCES elderly(id) ON DELETE CASCADE,
        caregiver_id    UUID      NOT NULL REFERENCES caregivers(id) ON DELETE CASCADE,
        status          TEXT      DEFAULT 'pending',
        source          VARCHAR(20) DEFAULT 'manual',
        created_at      TIMESTAMP DEFAULT NOW(),
        acknowledged_at TIMESTAMP
      )
    `);

    // ── 6. events (AI camera detections) ─────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS events (
        id               UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
        elderly_id       UUID             NOT NULL REFERENCES elderly(id) ON DELETE CASCADE,
        event_type       TEXT             NOT NULL,
        confidence       DOUBLE PRECISION,
        snapshot_url     TEXT,
        pose_data        JSONB,
        verified         BOOLEAN          DEFAULT false,
        is_false_positive BOOLEAN         DEFAULT false,
        verified_by      UUID             REFERENCES caregivers(id),
        verified_at      TIMESTAMP,
        alert_sent       BOOLEAN          DEFAULT false,
        alert_sent_at    TIMESTAMP,
        created_at       TIMESTAMP        DEFAULT NOW(),
        updated_at       TIMESTAMP        DEFAULT NOW()
      )
    `);

    // ── 7. cameras (Python AI module registration) ────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS cameras (
        id               UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
        camera_device_id TEXT      UNIQUE NOT NULL,
        elderly_id       UUID      REFERENCES elderly(id) ON DELETE SET NULL,
        status           TEXT      DEFAULT 'offline',
        updated_at       TIMESTAMP DEFAULT NOW()
      )
    `);

    // ══════════════════════════════════════════════════════════════════════════
    // SECONDARY TABLES (added in later sprints)
    // ══════════════════════════════════════════════════════════════════════════

    // ── 8. elder_locations ────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS elder_locations (
        elderly_id    UUID             PRIMARY KEY REFERENCES elderly(id) ON DELETE CASCADE,
        latitude      DOUBLE PRECISION NOT NULL,
        longitude     DOUBLE PRECISION NOT NULL,
        address       TEXT             DEFAULT '',
        is_home       BOOLEAN          DEFAULT false,
        battery_level INTEGER          DEFAULT NULL,
        updated_at    TIMESTAMP        DEFAULT NOW()
      )
    `);
    await client.query(`
      ALTER TABLE elder_locations
      ADD COLUMN IF NOT EXISTS battery_level INTEGER DEFAULT NULL
    `);

    // ── 9. voice_messages ─────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS voice_messages (
        id            UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
        caregiver_id  UUID      NOT NULL REFERENCES caregivers(id) ON DELETE CASCADE,
        elderly_id    UUID      NOT NULL REFERENCES elderly(id)    ON DELETE CASCADE,
        title         TEXT      NOT NULL,
        file_path     TEXT      NOT NULL,
        duration_secs INTEGER   DEFAULT 0,
        used_times    INTEGER   DEFAULT 0,
        is_saved      BOOLEAN   DEFAULT true,
        created_at    TIMESTAMP DEFAULT NOW()
      )
    `);
    await client.query(`
      ALTER TABLE voice_messages
      ADD COLUMN IF NOT EXISTS is_saved BOOLEAN DEFAULT true
    `);

    // ── 10. sos_requests — add source column (backward compat) ────────────────
    await client.query(`
      ALTER TABLE sos_requests
      ADD COLUMN IF NOT EXISTS source VARCHAR(20) DEFAULT 'manual'
    `);

    // ── 11. elder_safe_zones (geofencing) ─────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS elder_safe_zones (
        id              UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
        elderly_id      UUID             NOT NULL REFERENCES elderly(id)    ON DELETE CASCADE,
        caregiver_id    UUID             NOT NULL REFERENCES caregivers(id) ON DELETE CASCADE,
        center_lat      DOUBLE PRECISION NOT NULL,
        center_lng      DOUBLE PRECISION NOT NULL,
        radius_meters   INTEGER          NOT NULL DEFAULT 200,
        is_active       BOOLEAN          DEFAULT true,
        last_alerted_at TIMESTAMP        DEFAULT NULL,
        created_at      TIMESTAMP        DEFAULT NOW(),
        updated_at      TIMESTAMP        DEFAULT NOW(),
        UNIQUE(elderly_id)
      )
    `);

    // Add battery_alerted_at for low-battery cooldown
    await client.query(`
      ALTER TABLE elder_locations
      ADD COLUMN IF NOT EXISTS battery_alerted_at TIMESTAMP DEFAULT NULL
    `);

    // Add escalated_at to sos_requests for auto-escalation tracking
    await client.query(`
      ALTER TABLE sos_requests
      ADD COLUMN IF NOT EXISTS escalated_at TIMESTAMP DEFAULT NULL
    `);

    // ══════════════════════════════════════════════════════════════════════════
    // SMART PILLBOX TABLES
    // ══════════════════════════════════════════════════════════════════════════

    // ── 12. pill_slots — 3 physical slots per elderly person ─────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS pill_slots (
        id              UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
        elderly_id      UUID    NOT NULL REFERENCES elderly(id) ON DELETE CASCADE,
        slot_number     INTEGER NOT NULL CHECK (slot_number BETWEEN 1 AND 3),
        medication_name TEXT    NOT NULL DEFAULT '',
        notes           TEXT,
        is_active       BOOLEAN DEFAULT true,
        created_at      TIMESTAMP DEFAULT NOW(),
        updated_at      TIMESTAMP DEFAULT NOW(),
        UNIQUE(elderly_id, slot_number)
      )
    `);

    // ── 13. pill_schedules — scheduled times for each slot ───────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS pill_schedules (
        id             UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
        slot_id        UUID    NOT NULL REFERENCES pill_slots(id) ON DELETE CASCADE,
        elderly_id     UUID    NOT NULL REFERENCES elderly(id)   ON DELETE CASCADE,
        scheduled_time TIME    NOT NULL,
        label          TEXT,
        is_active      BOOLEAN DEFAULT true,
        created_at     TIMESTAMP DEFAULT NOW(),
        updated_at     TIMESTAMP DEFAULT NOW()
      )
    `);

    // ── 14. pill_logs — actual dose events (reported by ESP32) ───────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS pill_logs (
        id                  UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
        schedule_id         UUID    REFERENCES pill_schedules(id) ON DELETE SET NULL,
        slot_id             UUID    NOT NULL REFERENCES pill_slots(id) ON DELETE CASCADE,
        elderly_id          UUID    NOT NULL REFERENCES elderly(id)   ON DELETE CASCADE,
        scheduled_at        TIMESTAMP NOT NULL,
        status              TEXT    DEFAULT 'pending'
                              CHECK (status IN ('taken','missed','pending')),
        taken_at            TIMESTAMP,
        notified_caregiver  BOOLEAN DEFAULT false,
        notified_at         TIMESTAMP,
        created_at          TIMESTAMP DEFAULT NOW()
      )
    `);

    // ── 15. pillbox_devices — ESP32 device registration ──────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS pillbox_devices (
        id               UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
        elderly_id       UUID    NOT NULL REFERENCES elderly(id) ON DELETE CASCADE,
        device_mac       TEXT    UNIQUE NOT NULL,
        firmware_version TEXT,
        last_seen        TIMESTAMP,
        is_online        BOOLEAN DEFAULT false,
        created_at       TIMESTAMP DEFAULT NOW(),
        updated_at       TIMESTAMP DEFAULT NOW()
      )
    `);

    // ══════════════════════════════════════════════════════════════════════════
    // FEATURE: Date-range schedules
    // ══════════════════════════════════════════════════════════════════════════
    await client.query(`
      ALTER TABLE pill_schedules
        ADD COLUMN IF NOT EXISTS start_date DATE DEFAULT CURRENT_DATE,
        ADD COLUMN IF NOT EXISTS end_date   DATE DEFAULT NULL
    `);

    // ══════════════════════════════════════════════════════════════════════════
    // FEATURE: Elder quick preset messages
    // ══════════════════════════════════════════════════════════════════════════
    await client.query(`
      CREATE TABLE IF NOT EXISTS elder_messages (
        id           UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
        elderly_id   UUID      NOT NULL REFERENCES elderly(id) ON DELETE CASCADE,
        caregiver_id UUID      REFERENCES caregivers(id) ON DELETE SET NULL,
        message_key  VARCHAR(50) NOT NULL,
        message_en   TEXT      NOT NULL,
        message_ar   TEXT,
        is_read      BOOLEAN   DEFAULT false,
        read_at      TIMESTAMP,
        created_at   TIMESTAMPTZ DEFAULT NOW()
      )
    `);

    logger.success('✓ DB migrations applied');
  } catch (err) {
    logger.error('Migration error:', err.message);
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { runMigrations };
