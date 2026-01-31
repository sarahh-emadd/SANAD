-- Function to cleanup old load cell readings (keep last 30 days)
CREATE OR REPLACE FUNCTION cleanup_old_load_cell_readings()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM load_cell_readings 
    WHERE timestamp < NOW() - INTERVAL '30 days';
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_load_cell_readings IS 'Delete load cell readings older than 30 days';

-- Function to cleanup old camera health logs (keep last 7 days)
CREATE OR REPLACE FUNCTION cleanup_old_camera_health_logs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM camera_health_logs 
    WHERE timestamp < NOW() - INTERVAL '7 days';
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_camera_health_logs IS 'Delete camera health logs older than 7 days';

-- Function to cleanup old notifications (keep last 90 days, only if read)
CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM notifications 
    WHERE created_at < NOW() - INTERVAL '90 days' 
      AND read = true;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_notifications IS 'Delete read notifications older than 90 days';

-- Function to auto-expire QR tokens
CREATE OR REPLACE FUNCTION expire_old_qr_tokens()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    UPDATE qr_tokens 
    SET is_active = false 
    WHERE is_active = true 
      AND expires_at < NOW();
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION expire_old_qr_tokens IS 'Deactivate expired QR tokens';

-- Function to mark devices as offline if no recent heartbeat
CREATE OR REPLACE FUNCTION mark_offline_devices()
RETURNS TABLE(pillbox_count INTEGER, camera_count INTEGER) AS $$
DECLARE
    pillbox_count INTEGER;
    camera_count INTEGER;
BEGIN
    -- Mark pillboxes offline (no heartbeat for 5+ minutes)
    UPDATE pillboxes 
    SET status = 'offline' 
    WHERE status = 'online' 
      AND last_heartbeat < NOW() - INTERVAL '5 minutes';
    GET DIAGNOSTICS pillbox_count = ROW_COUNT;
    
    -- Mark cameras offline (no heartbeat for 2+ minutes)
    UPDATE cameras 
    SET status = 'offline' 
    WHERE status = 'online' 
      AND last_heartbeat < NOW() - INTERVAL '2 minutes';
    GET DIAGNOSTICS camera_count = ROW_COUNT;
    
    RETURN QUERY SELECT pillbox_count, camera_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mark_offline_devices IS 'Mark devices as offline if no recent heartbeat';

