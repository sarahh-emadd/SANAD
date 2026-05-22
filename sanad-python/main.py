"""
SANAD - Python AI Detection + WebRTC Streaming
───────────────────────────────────────────────
Correct boot sequence
─────────────────────
1. Open camera immediately (hardware always ready).
2. Start WebRTC streamer thread (always live).
3. Query the backend: which elder is this camera assigned to?
   • If found  → set config.ELDERLY_ID → AI starts on next frame.
   • If not yet → show "Waiting…" overlay, retry every 10 s.
4. Once ELDERLY_ID is set the AI runs forever — no caregiver
   action is needed. Monitoring is always on.

Just run:
    python main.py
"""

import logging
import sys
import asyncio
import threading
import time
import config

SHOW_PREVIEW = True   # ← set False for headless / Raspberry Pi

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)


# ── WebRTC thread ─────────────────────────────────────────────────────────────

def run_streamer(streamer):
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        loop.run_until_complete(streamer.start())
    except Exception as e:
        logger.error(f"WebRTC streamer error: {e}")
    finally:
        loop.close()


# ── Elderly-ID polling thread ─────────────────────────────────────────────────

def _poll_for_assignment(camera_device_id: str, poll_interval: int = 10):
    """
    Background thread: keeps asking the backend which elder this camera
    belongs to. Sets config.ELDERLY_ID as soon as it gets an answer.
    Stops polling once assigned.
    """
    from alert_sender import fetch_elderly_id

    logger.info(f"🔍 Polling for elderly assignment (device: {camera_device_id})")

    while config.ELDERLY_ID is None:
        elderly_id = fetch_elderly_id(camera_device_id)
        if elderly_id:
            config.ELDERLY_ID = elderly_id
            logger.info(f"✅ Assigned to elderly: {elderly_id}")
            logger.info("🚀 AI monitoring starting NOW")
            return  # done — camera.py will pick up ELDERLY_ID on next frame
        else:
            logger.info(f"⏳ Not assigned yet — retrying in {poll_interval} s…")
            time.sleep(poll_interval)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    logger.info("=" * 54)
    logger.info("  SANAD Camera Device Starting")
    logger.info("=" * 54)
    logger.info(f"  Server:       {config.SERVER_URL}")
    logger.info(f"  Preview mode: {'ON' if SHOW_PREVIEW else 'OFF'}")
    logger.info("=" * 54)

    from alert_sender import AlertSender
    from camera import Camera
    from webrtc_streamer import WebRTCStreamer, CAMERA_DEVICE_ID

    alert_sender = AlertSender()
    streamer     = WebRTCStreamer()
    camera       = Camera(
        alert_sender=alert_sender,
        streamer=streamer,
        show_preview=SHOW_PREVIEW,
    )

    # ── 1. Start WebRTC streamer (always live, handles its own elderly lookup)
    streamer_thread = threading.Thread(
        target=run_streamer,
        args=(streamer,),
        daemon=True,
        name="WebRTC-Streamer",
    )
    streamer_thread.start()
    logger.info("🔌 WebRTC streamer thread started")

    # ── 2. If elderly ID already hardcoded in config.py use it immediately
    if config.ELDERLY_ID:
        logger.info(f"✅ Elderly ID from config: {config.ELDERLY_ID}")
        logger.info("🚀 AI monitoring starting immediately")
    else:
        # ── 3. Otherwise: background thread polls the backend every 10 s
        #       Camera opens right away; AI kicks in the moment ID arrives.
        poll_thread = threading.Thread(
            target=_poll_for_assignment,
            args=(CAMERA_DEVICE_ID,),
            daemon=True,
            name="Assignment-Poller",
        )
        poll_thread.start()

    # ── 4. Start camera (always-on — AI activates as soon as ELDERLY_ID is set)
    try:
        camera.start()
    except RuntimeError as e:
        logger.error(str(e))
        sys.exit(1)
    except KeyboardInterrupt:
        logger.info("Stopped by user")


if __name__ == "__main__":
    main()
