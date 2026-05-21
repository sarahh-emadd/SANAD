-- Step 0: Clear any stuck transaction
ROLLBACK;

-- Step 1: Drop all dependent views
DROP VIEW IF EXISTS v_active_elderly CASCADE;
DROP VIEW IF EXISTS v_pillbox_health CASCADE;
DROP VIEW IF EXISTS v_camera_health CASCADE;
DROP VIEW IF EXISTS v_missed_doses CASCADE;
DROP VIEW IF EXISTS v_upcoming_doses CASCADE;

-- Step 2: Add new columns
ALTER TABLE caregivers
  ADD COLUMN IF NOT EXISTS first_name VARCHAR(100),
  ADD COLUMN IF NOT EXISTS last_name  VARCHAR(100);

-- Step 3: Migrate data
UPDATE caregivers
SET
  first_name = SPLIT_PART(name, ' ', 1),
  last_name  = CASE
                 WHEN POSITION(' ' IN name) > 0
                 THEN SUBSTRING(name FROM POSITION(' ' IN name) + 1)
                 ELSE NULL
               END
WHERE name IS NOT NULL AND first_name IS NULL;

-- Step 4: Fallbacks
UPDATE caregivers SET first_name = 'Unknown' WHERE first_name IS NULL;
UPDATE caregivers SET last_name  = ''        WHERE last_name  IS NULL;

-- Step 5: Constraints
ALTER TABLE caregivers ALTER COLUMN first_name SET NOT NULL;

-- Step 6: Drop old column
ALTER TABLE caregivers DROP COLUMN IF EXISTS name;

-- Step 7: Recreate views
CREATE OR REPLACE VIEW v_active_elderly AS
SELECT 
    e.*,
    (e.first_name || ' ' || e.last_name) AS full_name,
    (c.first_name || ' ' || c.last_name) AS caregiver_name,
    c.email                              AS caregiver_email,
    c.phone                              AS caregiver_phone,
    c.fcm_token                          AS caregiver_fcm_token,
    qt.expires_at                        AS qr_expires_at,
    qt.is_active                         AS qr_is_active,
    qt.manual_code                       AS qr_manual_code,
    CASE 
        WHEN qt.expires_at < NOW()                        THEN 'expired'
        WHEN qt.expires_at < NOW() + INTERVAL '7 days'   THEN 'expiring_soon'
        WHEN qt.is_active = true                          THEN 'active'
        ELSE 'inactive'
    END AS qr_status,
    CASE 
        WHEN e.last_seen IS NULL                          THEN 'never_connected'
        WHEN e.last_seen < NOW() - INTERVAL '2 hours'    THEN 'offline'
        WHEN e.last_seen < NOW() - INTERVAL '30 minutes' THEN 'away'
        ELSE 'online'
    END AS connection_status
FROM elderly e
JOIN caregivers c ON c.id = e.caregiver_id
LEFT JOIN qr_tokens qt ON qt.elderly_id = e.id AND qt.is_active = true
WHERE e.status = 'active';

CREATE OR REPLACE VIEW v_pillbox_health AS
SELECT 
    p.*,
    (e.first_name || ' ' || e.last_name) AS elderly_name,
    e.caregiver_id,
    CASE 
        WHEN p.last_heartbeat IS NULL                         THEN 'never_connected'
        WHEN p.last_heartbeat < NOW() - INTERVAL '5 minutes' THEN 'offline'
        ELSE 'online'
    END AS connection_status,
    COUNT(DISTINCT s.id)  AS total_slots,
    COUNT(DISTINCT sc.id) AS active_schedules,
    COALESCE(SUM(CASE WHEN s.current_count <= s.refill_threshold THEN 1 ELSE 0 END), 0) AS slots_needing_refill
FROM pillboxes p
JOIN elderly e ON e.id = p.elderly_id
LEFT JOIN slots s ON s.pillbox_id = p.id
LEFT JOIN schedules sc ON sc.slot_id = s.id AND sc.is_active = true
GROUP BY p.id, e.first_name, e.last_name, e.caregiver_id;

CREATE OR REPLACE VIEW v_camera_health AS
SELECT 
    c.*,
    (e.first_name || ' ' || e.last_name) AS elderly_name,
    e.caregiver_id,
    CASE 
        WHEN c.last_heartbeat IS NULL                         THEN 'never_connected'
        WHEN c.last_heartbeat < NOW() - INTERVAL '2 minutes' THEN 'offline'
        ELSE 'online'
    END AS connection_status,
    COUNT(ce.id) AS total_events,
    COUNT(ce.id) FILTER (WHERE ce.created_at > NOW() - INTERVAL '24 hours') AS events_last_24h,
    COUNT(ce.id) FILTER (WHERE ce.is_false_positive = true)                  AS false_positives,
    CASE 
        WHEN COUNT(ce.id) > 0 THEN
            ROUND(CAST(
                COUNT(ce.id) FILTER (WHERE ce.is_false_positive = true)::FLOAT
                / COUNT(ce.id)::FLOAT * 100 AS NUMERIC
            ), 2)
        ELSE 0
    END AS false_positive_rate
FROM cameras c
JOIN elderly e ON e.id = c.elderly_id
LEFT JOIN camera_events ce ON ce.camera_id = c.id
WHERE c.is_active = true
GROUP BY c.id, e.first_name, e.last_name, e.caregiver_id;

CREATE OR REPLACE VIEW v_missed_doses AS
SELECT 
    de.*,
    s.slot_number,
    s.medication_name,
    s.dosage,
    p.id                                 AS pillbox_id,
    e.id                                 AS elderly_id,
    (e.first_name || ' ' || e.last_name) AS elderly_name,
    e.caregiver_id
FROM dose_events de
JOIN slots s     ON s.id = de.slot_id
JOIN pillboxes p ON p.id = s.pillbox_id
JOIN elderly e   ON e.id = p.elderly_id
WHERE de.status = 'missed'
ORDER BY de.scheduled_time DESC;

CREATE OR REPLACE VIEW v_upcoming_doses AS
SELECT 
    de.*,
    s.slot_number,
    s.medication_name,
    s.dosage,
    p.id                                 AS pillbox_id,
    e.id                                 AS elderly_id,
    (e.first_name || ' ' || e.last_name) AS elderly_name,
    e.caregiver_id,
    sc.reminder_before_minutes
FROM dose_events de
JOIN slots s      ON s.id  = de.slot_id
JOIN schedules sc ON sc.id = de.schedule_id
JOIN pillboxes p  ON p.id  = s.pillbox_id
JOIN elderly e    ON e.id  = p.elderly_id
WHERE de.status = 'pending'
  AND de.scheduled_time BETWEEN NOW() AND NOW() + INTERVAL '24 hours'
ORDER BY de.scheduled_time ASC;

DO $$ BEGIN RAISE NOTICE '✓ Done! Migration complete and all views recreated.'; END $$;