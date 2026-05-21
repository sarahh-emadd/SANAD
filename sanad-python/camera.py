import sys
import cv2
import time
import logging
import os
from config import CAMERA_INDEX, FRAME_WIDTH, FRAME_HEIGHT, PROCESS_EVERY_N_FRAMES
import config

logger = logging.getLogger(__name__)

# ── Headless detection (fixed for macOS) ───────────────────────────────────────
is_linux = sys.platform.startswith("linux")

_HEADLESS = (
    os.environ.get("SANAD_HEADLESS", "0") == "1"
    or (is_linux and not os.environ.get("DISPLAY"))
)

if _HEADLESS:
    logger.info("🖥️  Headless mode — camera window disabled")
else:
    logger.info("🖥️  Preview window enabled")


# ✅ THIS WAS MISSING
class Camera:
    def __init__(self, alert_sender, streamer=None, show_preview=True):
        self.alert_sender = alert_sender
        self.streamer     = streamer
        self.detector     = None
        self.cap          = None
        self.show_preview = show_preview

    def _init_detector(self):
        """Initialize detector after elderly ID is assigned."""
        if self.detector is None:
            from detector import Detector
            self.detector = Detector(self.alert_sender)
            logger.info("✅ AI Detector initialized")

    def start(self):
        # Retry opening the camera — macOS holds the device for a few seconds
        # after a hard kill (VS Code close), so we retry instead of failing immediately.
        max_attempts = 10
        for attempt in range(1, max_attempts + 1):
            self.cap = cv2.VideoCapture(CAMERA_INDEX)
            self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, FRAME_WIDTH)
            self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, FRAME_HEIGHT)
            if self.cap.isOpened():
                break
            logger.warning(f"⏳ Camera not ready (attempt {attempt}/{max_attempts}) — retrying in 2s...")
            self.cap.release()
            time.sleep(2)
        else:
            raise RuntimeError(f"Cannot open camera at index {CAMERA_INDEX} after {max_attempts} attempts")

        logger.info(f"✅ Camera opened ({FRAME_WIDTH}x{FRAME_HEIGHT})")

        if _HEADLESS:
            logger.info("📷 Streaming without preview window (headless mode)")

        frame_count    = 0
        last_annotated = None

        try:
            while True:
                ret, frame = self.cap.read()
                if not ret:
                    time.sleep(0.1)
                    continue

                frame_count += 1

                # Send frame to WebRTC
                if self.streamer is not None:
                    self.streamer.push_frame(frame)

                # AI detection
                if config.ELDERLY_ID is not None:
                    self._init_detector()
                    if frame_count % PROCESS_EVERY_N_FRAMES == 0:
                        annotated, _ = self.detector.process_frame(frame)
                        last_annotated = annotated
                    else:
                        annotated = last_annotated if last_annotated is not None else frame
                else:
                    annotated = frame.copy()
                    cv2.putText(
                        annotated,
                        "Waiting for assignment...",
                        (10, 50),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.8,
                        (0, 165, 255),
                        2,
                    )

                # ✅ Show preview ONLY if allowed
                if not _HEADLESS and self.show_preview:
                    cv2.imshow("SANAD Camera", annotated)
                    if cv2.waitKey(1) & 0xFF == ord('q'):
                        break
                else:
                    time.sleep(0.001)

        finally:
            self.stop()

    def stop(self):
        if self.cap:
            self.cap.release()

        if not _HEADLESS and self.show_preview:
            cv2.destroyAllWindows()

        logger.info("Camera stopped")