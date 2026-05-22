import requests
import base64
import time
import logging
import config

logger = logging.getLogger(__name__)

def fetch_elderly_id(camera_device_id: str) -> str | None:
    """
    Ask the backend which elderly this camera is assigned to.
    Returns the elderly UUID string, or None if not assigned yet.
    Called once at startup (and retried every 10 s until found).
    """
    try:
        url = f"{config.SERVER_URL}/api/v1/dev/camera-device/{camera_device_id}"
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            data = response.json().get("data", {})
            return data.get("elderly_id")
    except requests.exceptions.ConnectionError:
        logger.warning("⚠ Server not reachable — will retry")
    except Exception as e:
        logger.warning(f"⚠ fetch_elderly_id error: {e}")
    return None


class AlertSender:
    def __init__(self):
        self.last_alert_time = {}  # event_type -> timestamp

    def can_send_alert(self, event_type: str) -> bool:
        """Check if cooldown has passed for this event type."""
        last = self.last_alert_time.get(event_type, 0)
        return (time.time() - last) >= config.ALERT_COOLDOWN_SECONDS

    def send_event(self, event_type: str, confidence: float, frame=None, pose_data: dict = None):
        """Send detected event to Node.js backend."""
        if not self.can_send_alert(event_type):
            logger.debug(f"Cooldown active for {event_type}, skipping alert")
            return False

        # Encode snapshot as base64 if frame provided
        snapshot_base64 = None
        if frame is not None:
            try:
                import cv2
                _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
                snapshot_base64 = base64.b64encode(buffer).decode('utf-8')
            except Exception as e:
                logger.warning(f"Failed to encode snapshot: {e}")

        payload = {
            "elderly_id": config.ELDERLY_ID,
            "event_type": event_type,
            "confidence": confidence,
            "snapshot_base64": snapshot_base64,
            "pose_data": pose_data,
        }

        try:
            response = requests.post(
                f"{config.SERVER_URL}/api/v1/events",
                json=payload,
                timeout=10
            )
            if response.status_code == 201:
                self.last_alert_time[event_type] = time.time()
                logger.warning(f"✅ Alert sent: {event_type} (confidence: {confidence:.0%})")
                return True
            else:
                logger.error(f"❌ Server rejected alert: {response.status_code} - {response.text}")
                return False
        except requests.exceptions.ConnectionError:
            logger.error(f"❌ Cannot connect to server at {config.SERVER_URL}")
            return False
        except requests.exceptions.Timeout:
            logger.error("❌ Server timeout")
            return False
        except Exception as e:
            logger.error(f"❌ Failed to send alert: {e}")
            return False