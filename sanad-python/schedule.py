import requests
import logging
import config

# Fallback defaults if server unreachable
DEFAULT_WAKE_HOUR  = 8   # 8 AM
DEFAULT_SLEEP_HOUR = 22  # 10 PM

logger = logging.getLogger(__name__)


def fetch_sleep_schedule() -> dict:
    """
    Fetch the caregiver-defined sleep schedule for this elderly from backend.
    Returns: { 'wake_hour': int, 'sleep_hour': int }
    Falls back to defaults if server is unreachable.
    """
    try:
        response = requests.get(
            f"{config.SERVER_URL}/api/v1/elderly/{config.ELDERLY_ID}/schedule",
            timeout=5
        )
        if response.status_code == 200:
            data = response.json().get("data", {})
            wake_time  = data.get("typical_wake_time", "08:00")   # "HH:MM"
            sleep_time = data.get("typical_sleep_time", "22:00")  # "HH:MM"

            wake_hour  = int(wake_time.split(":")[0])
            sleep_hour = int(sleep_time.split(":")[0])

            logger.info(f"✅ Sleep schedule loaded — awake: {wake_hour}:00 → {sleep_hour}:00")
            return {"wake_hour": wake_hour, "sleep_hour": sleep_hour}

        else:
            logger.warning(f"⚠ Could not fetch schedule ({response.status_code}), using defaults")

    except Exception as e:
        logger.warning(f"⚠ Schedule fetch failed: {e}, using defaults")

    return {"wake_hour": DEFAULT_WAKE_HOUR, "sleep_hour": DEFAULT_SLEEP_HOUR}