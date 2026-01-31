CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
-- 1. CAREGIVERS TABLE
CREATE TABLE caregivers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid VARCHAR(128) UNIQUE NOT NULL, -- Link to Firebase user
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    photo_url TEXT,
    
    -- Firebase Cloud Messaging token for push notifications
    fcm_token TEXT,
    
    -- Auth metadata (synced from Firebase)
    email_verified BOOLEAN DEFAULT false,
    phone_verified BOOLEAN DEFAULT false,
    auth_provider VARCHAR(50) DEFAULT 'email', -- 'email', 'google.com', 'phone'
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_caregivers_firebase_uid ON caregivers(firebase_uid);
CREATE INDEX idx_caregivers_email ON caregivers(email);

COMMENT ON TABLE caregivers IS 'Caregiver accounts (authenticated via Firebase)';
COMMENT ON COLUMN caregivers.firebase_uid IS 'Firebase Authentication user ID';
COMMENT ON COLUMN caregivers.fcm_token IS 'Firebase Cloud Messaging token for push notifications';

-- 2. ELDERLY TABLE

CREATE TABLE elderly (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    caregiver_id UUID REFERENCES caregivers(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    photo_url TEXT,
    device_token TEXT, -- Firebase FCM token for elderly phone
    last_seen TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived', 'deceased')),
    is_connected BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_elderly_caregiver ON elderly(caregiver_id);
CREATE INDEX idx_elderly_status ON elderly(status);
CREATE INDEX idx_elderly_last_seen ON elderly(last_seen DESC);

COMMENT ON TABLE elderly IS 'Elderly persons being monitored';
COMMENT ON COLUMN elderly.last_seen IS 'Last time elderly phone app was active';
COMMENT ON COLUMN elderly.status IS 'Account status: active, inactive, archived, deceased';
COMMENT ON COLUMN elderly.is_connected IS 'Whether elderly phone is currently connected';

-- 3. QR TOKENS TABLE

CREATE TABLE qr_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    elderly_id UUID REFERENCES elderly(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    manual_code VARCHAR(6) UNIQUE NOT NULL, -- 6-digit code for manual entry
    expires_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT true,
    used_at TIMESTAMP,
    revoked_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_qr_tokens_elderly ON qr_tokens(elderly_id);
CREATE INDEX idx_qr_tokens_token ON qr_tokens(token) WHERE is_active = true;
CREATE INDEX idx_qr_tokens_manual_code ON qr_tokens(manual_code) WHERE is_active = true;
CREATE INDEX idx_qr_tokens_active ON qr_tokens(is_active, expires_at);

COMMENT ON TABLE qr_tokens IS 'QR codes for elderly device pairing (30-day expiration)';
COMMENT ON COLUMN qr_tokens.manual_code IS '6-digit code for manual entry if QR scan fails';

-- 4. ELDERLY CONNECTIONS TABLE

CREATE TABLE elderly_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    elderly_id UUID REFERENCES elderly(id) ON DELETE CASCADE,
    qr_token_id UUID REFERENCES qr_tokens(id) ON DELETE SET NULL,
    connected_at TIMESTAMP NOT NULL,
    disconnected_at TIMESTAMP,
    disconnection_reason VARCHAR(50), -- expired, manual_disconnect, new_connection, manual_revoke
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_connections_elderly ON elderly_connections(elderly_id);
CREATE INDEX idx_connections_active ON elderly_connections(elderly_id, disconnected_at) WHERE disconnected_at IS NULL;

COMMENT ON TABLE elderly_connections IS 'Connection history for elderly devices';


-- 5. PILLBOXES TABLE

CREATE TABLE pillboxes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    elderly_id UUID REFERENCES elderly(id) ON DELETE CASCADE,
    device_id VARCHAR(100) UNIQUE NOT NULL, -- ESP32 MAC address
    device_secret VARCHAR(255) NOT NULL, -- For authentication
    status VARCHAR(20) DEFAULT 'offline' CHECK (status IN ('online', 'offline', 'error')),
    battery_level INT CHECK (battery_level >= 0 AND battery_level <= 100),
    wifi_strength INT,
    last_heartbeat TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_pillboxes_elderly ON pillboxes(elderly_id);
CREATE INDEX idx_pillboxes_device_id ON pillboxes(device_id);
CREATE INDEX idx_pillboxes_status ON pillboxes(status);
CREATE INDEX idx_pillboxes_last_heartbeat ON pillboxes(last_heartbeat DESC);

COMMENT ON TABLE pillboxes IS 'ESP32-based smart pillbox devices';
COMMENT ON COLUMN pillboxes.device_id IS 'ESP32 MAC address';
COMMENT ON COLUMN pillboxes.device_secret IS 'Secret key for device authentication';

-- 6. SLOTS TABLE

CREATE TABLE slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pillbox_id UUID REFERENCES pillboxes(id) ON DELETE CASCADE,
    slot_number INT NOT NULL CHECK (slot_number >= 1 AND slot_number <= 4),
    medication_name VARCHAR(255),
    dosage VARCHAR(100),
    instructions TEXT,
    refill_threshold INT DEFAULT 3 CHECK (refill_threshold >= 0),
    current_count INT DEFAULT 0 CHECK (current_count >= 0),
    last_refill TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(pillbox_id, slot_number)
);

CREATE INDEX idx_slots_pillbox ON slots(pillbox_id);
CREATE INDEX idx_slots_low_count ON slots(current_count, refill_threshold) WHERE current_count <= refill_threshold;

COMMENT ON TABLE slots IS 'Physical compartments in pillboxes (1-4 per device)';
COMMENT ON COLUMN slots.refill_threshold IS 'Alert when pills remaining reach this number';
COMMENT ON COLUMN slots.current_count IS 'Current number of pills in slot';

-- 7. SCHEDULES TABLE

CREATE TABLE schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slot_id UUID REFERENCES slots(id) ON DELETE CASCADE,
    time TIME NOT NULL,
    days_of_week VARCHAR(20) DEFAULT '1234567', -- 1=Monday, 7=Sunday, '1234567' = daily
    is_active BOOLEAN DEFAULT true,
    reminder_before_minutes INT DEFAULT 5 CHECK (reminder_before_minutes >= 0),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_schedules_slot ON schedules(slot_id);
CREATE INDEX idx_schedules_active ON schedules(is_active, time) WHERE is_active = true;
CREATE INDEX idx_schedules_time ON schedules(time);

COMMENT ON TABLE schedules IS 'Medication dose schedules';
COMMENT ON COLUMN schedules.days_of_week IS 'Days when schedule is active (1=Mon, 7=Sun). "1234567"=daily, "12345"=weekdays';
COMMENT ON COLUMN schedules.reminder_before_minutes IS 'Minutes before scheduled time to send reminder';

-- 8. DOSE EVENTS TABLE

CREATE TABLE dose_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id UUID REFERENCES schedules(id) ON DELETE CASCADE,
    slot_id UUID REFERENCES slots(id) ON DELETE CASCADE,
    scheduled_time TIMESTAMP NOT NULL,
    actual_time TIMESTAMP,
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'taken', 'missed', 'skipped')),
    weight_before FLOAT,
    weight_after FLOAT,
    reminder_sent BOOLEAN DEFAULT false,
    reminder_sent_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_dose_events_schedule ON dose_events(schedule_id);
CREATE INDEX idx_dose_events_slot ON dose_events(slot_id);
CREATE INDEX idx_dose_events_status ON dose_events(status);
CREATE INDEX idx_dose_events_scheduled ON dose_events(scheduled_time, status);
CREATE INDEX idx_dose_events_pending ON dose_events(status, scheduled_time) WHERE status = 'pending';

COMMENT ON TABLE dose_events IS 'Individual dose instances (taken/missed)';
COMMENT ON COLUMN dose_events.status IS 'pending, taken, missed, skipped';

-- 9. LOAD CELL READINGS TABLE

CREATE TABLE load_cell_readings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slot_id UUID REFERENCES slots(id) ON DELETE CASCADE,
    weight FLOAT NOT NULL CHECK (weight >= 0),
    timestamp TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_load_cell_slot ON load_cell_readings(slot_id);
CREATE INDEX idx_load_cell_timestamp ON load_cell_readings(slot_id, timestamp DESC);

COMMENT ON TABLE load_cell_readings IS 'Weight sensor data from pillboxes';

-- 10. CAMERAS TABLE

CREATE TABLE cameras (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    elderly_id UUID REFERENCES elderly(id) ON DELETE CASCADE,
    camera_id VARCHAR(100) UNIQUE NOT NULL, -- Unique hardware ID (MAC, serial number)
    camera_secret VARCHAR(255) NOT NULL, -- For authentication
    name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    status VARCHAR(20) DEFAULT 'offline' CHECK (status IN ('online', 'offline', 'error')),
    is_active BOOLEAN DEFAULT true,
    
    -- Camera Specifications
    model VARCHAR(100),
    resolution VARCHAR(20),
    fps INT DEFAULT 10 CHECK (fps > 0),
    
    -- AI Settings
    ai_model VARCHAR(50) DEFAULT 'fall_detection_v1',
    confidence_threshold FLOAT DEFAULT 0.75 CHECK (confidence_threshold >= 0 AND confidence_threshold <= 1),
    detection_interval_seconds INT DEFAULT 5 CHECK (detection_interval_seconds > 0),
    
    -- Health Monitoring
    last_heartbeat TIMESTAMP,
    last_frame_received TIMESTAMP,
    total_events_detected INT DEFAULT 0 CHECK (total_events_detected >= 0),
    false_positive_count INT DEFAULT 0 CHECK (false_positive_count >= 0),
    
    -- Network
    ip_address VARCHAR(45),
    wifi_strength INT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_cameras_elderly ON cameras(elderly_id);
CREATE INDEX idx_cameras_camera_id ON cameras(camera_id);
CREATE INDEX idx_cameras_status ON cameras(status) WHERE is_active = true;
CREATE INDEX idx_cameras_active ON cameras(is_active);
CREATE INDEX idx_cameras_last_heartbeat ON cameras(last_heartbeat DESC);

COMMENT ON TABLE cameras IS 'AI-enabled camera devices for fall detection';
COMMENT ON COLUMN cameras.confidence_threshold IS 'Minimum confidence (0-1) to trigger alert';
COMMENT ON COLUMN cameras.detection_interval_seconds IS 'How often to run AI detection';

-- 11. CAMERA EVENTS TABLE

CREATE TABLE camera_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    camera_id UUID REFERENCES cameras(id) ON DELETE CASCADE,
    elderly_id UUID REFERENCES elderly(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL CHECK (event_type IN ('fall_detected', 'unusual_activity', 'person_detected')),
    confidence FLOAT NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
    
    -- Event Details
    image_url TEXT,
    video_url TEXT,
    bounding_box JSON,
    
    -- Verification
    verified BOOLEAN DEFAULT false,
    verified_by UUID REFERENCES caregivers(id) ON DELETE SET NULL,
    verified_at TIMESTAMP,
    is_false_positive BOOLEAN DEFAULT false,
    
    -- Actions Taken
    alert_sent BOOLEAN DEFAULT false,
    alert_sent_at TIMESTAMP,
    response_time_seconds INT,
    
    -- Additional Context
    notes TEXT,
    metadata JSON,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_camera_events_camera ON camera_events(camera_id);
CREATE INDEX idx_camera_events_elderly ON camera_events(elderly_id);
CREATE INDEX idx_camera_events_type ON camera_events(event_type);
CREATE INDEX idx_camera_events_unverified ON camera_events(verified) WHERE verified = false;
CREATE INDEX idx_camera_events_created ON camera_events(created_at DESC);
CREATE INDEX idx_camera_events_alert ON camera_events(alert_sent, created_at) WHERE alert_sent = false;
COMMENT ON TABLE camera_events IS 'Events detected by cameras (falls, unusual activity)';
COMMENT ON COLUMN camera_events.bounding_box IS 'JSON: {x, y, width, height}';
COMMENT ON COLUMN camera_events.metadata IS 'Additional AI data (pose estimation, etc.)';

-- 12. CAMERA HEALTH LOGS TABLE

CREATE TABLE camera_health_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    camera_id UUID REFERENCES cameras(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL CHECK (status IN ('online', 'offline', 'error', 'rebooting')),
    error_message TEXT,
    cpu_usage FLOAT CHECK (cpu_usage >= 0 AND cpu_usage <= 100),
    memory_usage FLOAT CHECK (memory_usage >= 0 AND memory_usage <= 100),
    temperature FLOAT,
    timestamp TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_camera_health_camera ON camera_health_logs(camera_id);
CREATE INDEX idx_camera_health_timestamp ON camera_health_logs(timestamp DESC);
CREATE INDEX idx_camera_health_errors ON camera_health_logs(camera_id, status) WHERE status = 'error';

COMMENT ON TABLE camera_health_logs IS 'Camera device health monitoring logs';

-- 13. NOTIFICATIONS TABLE

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL,
    recipient_type VARCHAR(20) NOT NULL CHECK (recipient_type IN ('caregiver', 'elderly')),
    type VARCHAR(50) NOT NULL CHECK (type IN (
        'missed_dose', 
        'refill_needed', 
        'fall_alert', 
        'sos', 
        'low_battery',
        'device_offline',
        'elderly_connected',
        'elderly_disconnected',
        'camera_offline',
        'qr_expiring_soon'
    )),
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    
    -- Related entities (optional references)
    related_entity_type VARCHAR(50), -- pillbox, camera, dose_event, etc.
    related_entity_id UUID,
    
    -- Status
    read BOOLEAN DEFAULT false,
    read_at TIMESTAMP,
    sent BOOLEAN DEFAULT false,
    sent_at TIMESTAMP,
    
    -- Firebase Cloud Messaging
    fcm_message_id VARCHAR(255),
    
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_notifications_recipient ON notifications(recipient_id, recipient_type);
CREATE INDEX idx_notifications_unread ON notifications(recipient_id, read) WHERE read = false;
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);
CREATE INDEX idx_notifications_unsent ON notifications(sent) WHERE sent = false;

COMMENT ON TABLE notifications IS 'Push notifications sent to users';

-- 14. SOS EVENTS TABLE

CREATE TABLE sos_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    elderly_id UUID REFERENCES elderly(id) ON DELETE CASCADE,
    caregiver_id UUID REFERENCES caregivers(id) ON DELETE CASCADE,
    location_lat FLOAT CHECK (location_lat >= -90 AND location_lat <= 90),
    location_lng FLOAT CHECK (location_lng >= -180 AND location_lng <= 180),
    location_accuracy FLOAT, -- meters
    resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMP,
    resolved_by UUID REFERENCES caregivers(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_sos_events_elderly ON sos_events(elderly_id);
CREATE INDEX idx_sos_events_caregiver ON sos_events(caregiver_id);
CREATE INDEX idx_sos_events_unresolved ON sos_events(resolved) WHERE resolved = false;
CREATE INDEX idx_sos_events_created ON sos_events(created_at DESC);

COMMENT ON TABLE sos_events IS 'Emergency SOS button activations';







