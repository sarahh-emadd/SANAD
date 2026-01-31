-- View: Active elderly with connection status
CREATE OR REPLACE VIEW v_active_elderly AS
SELECT 
    e.*,
    c.name as caregiver_name,
    c.email as caregiver_email,
    c.phone as caregiver_phone,
    c.fcm_token as caregiver_fcm_token,
    qt.expires_at as qr_expires_at,
    qt.is_active as qr_is_active,
    qt.manual_code as qr_manual_code,
    CASE 
        WHEN qt.expires_at < NOW() THEN 'expired'
        WHEN qt.expires_at < NOW() + INTERVAL '7 days' THEN 'expiring_soon'
        WHEN qt.is_active = true THEN 'active'
        ELSE 'inactive'
    END as qr_status,
    CASE 
        WHEN e.last_seen IS NULL THEN 'never_connected'
        WHEN e.last_seen < NOW() - INTERVAL '2 hours' THEN 'offline'
        WHEN e.last_seen < NOW() - INTERVAL '30 minutes' THEN 'away'
        ELSE 'online'
    END as connection_status
FROM elderly e
JOIN caregivers c ON c.id = e.caregiver_id
LEFT JOIN qr_tokens qt ON qt.elderly_id = e.id AND qt.is_active = true
WHERE e.status = 'active';

-- View: Pillbox health summary
CREATE OR REPLACE VIEW v_pillbox_health AS
SELECT 
    p.*,
    e.name as elderly_name,
    e.caregiver_id,
    CASE 
        WHEN p.last_heartbeat IS NULL THEN 'never_connected'
        WHEN p.last_heartbeat < NOW() - INTERVAL '5 minutes' THEN 'offline'
        ELSE 'online'
    END as connection_status,
    COUNT(DISTINCT s.id) as total_slots,
    COUNT(DISTINCT sc.id) as active_schedules,
    COALESCE(SUM(CASE WHEN s.current_count <= s.refill_threshold THEN 1 ELSE 0 END), 0) as slots_needing_refill
FROM pillboxes p
JOIN elderly e ON e.id = p.elderly_id
LEFT JOIN slots s ON s.pillbox_id = p.id
LEFT JOIN schedules sc ON sc.slot_id = s.id AND sc.is_active = true
GROUP BY p.id, e.name, e.caregiver_id;

-- View: Camera health summary 
CREATE OR REPLACE VIEW v_camera_health AS
SELECT 
    c.*,
    e.name as elderly_name,
    e.caregiver_id,
    CASE 
        WHEN c.last_heartbeat IS NULL THEN 'never_connected'
        WHEN c.last_heartbeat < NOW() - INTERVAL '2 minutes' THEN 'offline'
        ELSE 'online'
    END as connection_status,
    COUNT(ce.id) as total_events,
    COUNT(ce.id) FILTER (WHERE ce.created_at > NOW() - INTERVAL '24 hours') as events_last_24h,
    COUNT(ce.id) FILTER (WHERE ce.is_false_positive = true) as false_positives,
    CASE 
        WHEN COUNT(ce.id) > 0 THEN 
            ROUND(
                CAST(
                    (COUNT(ce.id) FILTER (WHERE ce.is_false_positive = true)::FLOAT / COUNT(ce.id)::FLOAT * 100) 
                    AS NUMERIC
                ), 
                2
            )
        ELSE 0
    END as false_positive_rate
FROM cameras c
JOIN elderly e ON e.id = c.elderly_id
LEFT JOIN camera_events ce ON ce.camera_id = c.id
WHERE c.is_active = true
GROUP BY c.id, e.name, e.caregiver_id;

-- View: Missed doses summary

CREATE OR REPLACE VIEW v_missed_doses AS
SELECT 
    de.*,
    s.slot_number,
    s.medication_name,
    s.dosage,
    p.id as pillbox_id,
    e.id as elderly_id,
    e.name as elderly_name,
    e.caregiver_id
FROM dose_events de
JOIN slots s ON s.id = de.slot_id
JOIN pillboxes p ON p.id = s.pillbox_id
JOIN elderly e ON e.id = p.elderly_id
WHERE de.status = 'missed'
ORDER BY de.scheduled_time DESC;

-- View: Upcoming doses (next 24 hours)

CREATE OR REPLACE VIEW v_upcoming_doses AS
SELECT 
    de.*,
    s.slot_number,
    s.medication_name,
    s.dosage,
    p.id as pillbox_id,
    e.id as elderly_id,
    e.name as elderly_name,
    e.caregiver_id,
    sc.reminder_before_minutes
FROM dose_events de
JOIN slots s ON s.id = de.slot_id
JOIN schedules sc ON sc.id = de.schedule_id
JOIN pillboxes p ON p.id = s.pillbox_id
JOIN elderly e ON e.id = p.elderly_id
WHERE de.status = 'pending'
  AND de.scheduled_time BETWEEN NOW() AND NOW() + INTERVAL '24 hours'
ORDER BY de.scheduled_time ASC;
