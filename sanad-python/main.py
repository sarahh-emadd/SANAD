"""
SANAD - Python AI Detection + WebRTC Streaming
───────────────────────────────────────────────
Just run:
    python main.py
"""

import logging
import sys
import asyncio
import threading
import config

# 🔥 NEW: control preview here
SHOW_PREVIEW = True   # ← change to False if you want headless mode again

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)


def run_streamer(streamer):
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        loop.run_until_complete(streamer.start())
    except Exception as e:
        logger.error(f"WebRTC streamer error: {e}")
    finally:
        loop.close()


def main():
    logger.info("=" * 50)
    logger.info("  SANAD Camera Device Starting")
    logger.info("=" * 50)
    logger.info(f"  Server: {config.SERVER_URL}")
    logger.info(f"  Preview Mode: {'ON' if SHOW_PREVIEW else 'OFF'}")
    logger.info("  Waiting for elderly assignment...")
    logger.info("=" * 50)

    from alert_sender import AlertSender
    from detector import Detector
    from camera import Camera
    from webrtc_streamer import WebRTCStreamer

    alert_sender = AlertSender()
    streamer     = WebRTCStreamer()

    # 👇 PASS preview flag to camera
    camera = Camera(
        alert_sender=alert_sender,
        streamer=streamer,
        show_preview=SHOW_PREVIEW   # 🔥 important
    )

    streamer_thread = threading.Thread(
        target=run_streamer,
        args=(streamer,),
        daemon=True
    )
    streamer_thread.start()
    logger.info("🔌 WebRTC streamer started — waiting for assignment")

    try:
        camera.start()
    except RuntimeError as e:
        logger.error(str(e))
        sys.exit(1)
    except KeyboardInterrupt:
        logger.info("Stopped by user")


if __name__ == "__main__":
    main()