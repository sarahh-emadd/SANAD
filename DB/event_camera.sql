CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    elderly_id UUID REFERENCES cd /Users/sarah/Documents/GradProject/PROJECT/SANAD/server
npm install socket.io minio multer --save(id) ON DELETE CASCADE,
    
    event_type VARCHAR(50) NOT NULL 
        CHECK (event_type IN ('fall', 'inactivity', 'sleeping')),
    confidence FLOAT NOT NULL 
        CHECK (confidence >= 0 AND confidence <= 1),
    
    snapshot_url TEXT,
    video_url TEXT,
    
    alert_sent BOOLEAN DEFAULT false,
    alert_sent_at TIMESTAMP,
    
    verified BOOLEAN DEFAULT false,
    is_false_positive BOOLEAN DEFAULT false,
    verified_by UUID REFERENCES caregivers(id) ON DELETE SET NULL,
    verified_at TIMESTAMP,
    
    pose_data JSON,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_events_elderly ON events(elderly_id);
CREATE INDEX idx_events_type ON events(event_type);
CREATE INDEX idx_events_created ON events(created_at DESC);
CREATE INDEX idx_events_unverified ON events(verified) WHERE verified = false;
CREATE INDEX idx_events_alert ON events(alert_sent) WHERE alert_sent = false;