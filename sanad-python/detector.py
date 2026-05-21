import time
import logging
import cv2
import numpy as np
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

from config import (
    FALL_CONFIRMATION_SECONDS,
    INACTIVITY_THRESHOLD_SECONDS, INACTIVITY_MOVEMENT_PIXELS,
    SLEEP_ANGLE_THRESHOLD, SLEEP_CONFIRMATION_SECONDS,
    FALL_CONFIDENCE, INACTIVITY_CONFIDENCE, SLEEP_CONFIDENCE,
    ALERT_COOLDOWN_SECONDS,
)
from schedule import fetch_sleep_schedule

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────
# Production Fall Detection Algorithm
# Works even if face is covered (face-down falls)
# ─────────────────────────────────────────────
def analyze_fall(landmarks):
    """
    3-rule weighted fall detection:
    - Rule 1: Torso horizontal     (50% weight)
    - Rule 2: Legs collapsed       (30% weight)
    - Rule 3: Head at torso level  (20% weight, optional)
    Threshold: 70% confidence
    """
    if not landmarks or len(landmarks) < 33:
        return False, 0.0, "Incomplete landmarks"

    nose          = landmarks[0]
    left_shoulder = landmarks[11]
    right_shoulder= landmarks[12]
    left_hip      = landmarks[23]
    right_hip     = landmarks[24]
    left_knee     = landmarks[25]
    right_knee    = landmarks[26]
    left_ankle    = landmarks[27]
    right_ankle   = landmarks[28]

    avg_hip_y      = (left_hip.y      + right_hip.y)      / 2
    avg_shoulder_y = (left_shoulder.y + right_shoulder.y) / 2
    avg_knee_y     = (left_knee.y     + right_knee.y)     / 2
    avg_ankle_y    = (left_ankle.y    + right_ankle.y)    / 2

    confidence = 0.0
    reasons    = []

    # Rule 1: Torso horizontal (50%)
    shoulder_hip_diff = abs(avg_hip_y - avg_shoulder_y)
    if shoulder_hip_diff < 0.15:
        confidence += 0.50
        reasons.append("Torso horizontal")
    elif shoulder_hip_diff < 0.25:
        confidence += 0.25
        reasons.append("Torso tilted")

    # Rule 2: Legs collapsed (30%)
    knee_hip_diff  = abs(avg_knee_y  - avg_hip_y)
    ankle_hip_diff = abs(avg_ankle_y - avg_hip_y)
    if knee_hip_diff < 0.20 and ankle_hip_diff < 0.30:
        confidence += 0.30
        reasons.append("Legs collapsed")
    elif knee_hip_diff < 0.30 or ankle_hip_diff < 0.40:
        confidence += 0.15
        reasons.append("Legs bent")

    # Rule 3: Head at torso level (20%, only if nose visible)
    nose_hip_diff = avg_hip_y - nose.y
    nose_valid    = abs(nose_hip_diff) >= 0.02
    if nose_valid and nose_hip_diff >= 0:
        if nose_hip_diff < 0.08:
            confidence += 0.20
            reasons.append("Head at torso level")
        elif nose_hip_diff < 0.15:
            confidence += 0.10
    elif not nose_valid:
        reasons.append("Face covered")

    confidence = min(confidence, 1.0)
    is_fall    = confidence >= 0.70
    reason_str = ", ".join(reasons) if reasons else "Normal posture"

    return is_fall, confidence, reason_str


# ─────────────────────────────────────────────
# Detection State
# ─────────────────────────────────────────────
class DetectionState:
    def __init__(self):
        # Fall
        self.fall_start_time  = None
        self.fall_counted     = False
        self.last_fall_time   = 0

        # Inactivity
        self.last_movement_time = time.time()
        self.prev_keypoints     = None

        # Sleeping
        self.sleep_start_time = None


# ─────────────────────────────────────────────
# Detector
# ─────────────────────────────────────────────
class Detector:
    def __init__(self, alert_sender):
        # Use VIDEO mode for better performance (same as test3)
        base_options = python.BaseOptions(model_asset_path='pose_landmarker.task')
        options = vision.PoseLandmarkerOptions(
            base_options=base_options,
            running_mode=vision.RunningMode.VIDEO,
            num_poses=1,
            min_pose_detection_confidence=0.5,
            min_pose_presence_confidence=0.5,
            min_tracking_confidence=0.5,
        )
        self.detector     = vision.PoseLandmarker.create_from_options(options)
        self.alert_sender = alert_sender
        self.state        = DetectionState()
        self.timestamp_ms = 0

        schedule         = fetch_sleep_schedule()
        self.wake_hour   = schedule["wake_hour"]
        self.sleep_hour  = schedule["sleep_hour"]

        logger.info("✅ Detector initialized (VIDEO mode)")

    def process_frame(self, frame):
        self.timestamp_ms += 33  # ~30fps

        rgb      = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        result   = self.detector.detect_for_video(mp_image, self.timestamp_ms)

        annotated = frame.copy()

        if result.pose_landmarks and len(result.pose_landmarks) > 0:
            landmarks = result.pose_landmarks[0]
            self._draw_landmarks(annotated, landmarks, frame.shape)
            self._check_fall(landmarks, frame, annotated)
            self._check_inactivity(landmarks, frame, annotated)
            self._check_sleeping(landmarks, frame, annotated)
            pose_data = self._extract_pose_data(landmarks, frame.shape)
        else:
            self.state.fall_start_time  = None
            self.state.sleep_start_time = None
            pose_data = None
            cv2.putText(annotated, "No person detected", (10, 50),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)

        return annotated, pose_data

    # ── Fall Detection ────────────────────────────────
    def _check_fall(self, landmarks, frame, annotated):
        is_fall, confidence, reason = analyze_fall(landmarks)

        # Visual confidence bar
        bar_w = int(confidence * 400)
        cv2.rectangle(annotated, (10, 115), (410, 135), (50, 50, 50), -1)
        color = (0, 0, 255) if confidence >= 0.70 else (0, 165, 255) if confidence >= 0.55 else (0, 255, 0)
        cv2.rectangle(annotated, (10, 115), (10 + bar_w, 135), color, -1)
        cv2.putText(annotated, f"Fall conf: {confidence*100:.0f}%  {reason[:40]}",
                    (10, 110), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1)

        current_time = time.time()

        if is_fall:
            if self.state.fall_start_time is None:
                self.state.fall_start_time = current_time
                self.state.fall_counted    = False
                logger.debug(f"Possible fall — conf: {confidence:.0%}")

            elif not self.state.fall_counted:
                time_down = current_time - self.state.fall_start_time

                if time_down >= FALL_CONFIRMATION_SECONDS:
                    if (current_time - self.state.last_fall_time) > ALERT_COOLDOWN_SECONDS:
                        self.state.fall_counted  = True
                        self.state.last_fall_time = current_time
                        self._draw_alert(annotated, "FALL DETECTED", (0, 0, 255))
                        self.alert_sender.send_event("fall", confidence, frame,
                                                     self._extract_pose_data(landmarks, frame.shape))
                    else:
                        remaining = ALERT_COOLDOWN_SECONDS - (current_time - self.state.last_fall_time)
                        cv2.putText(annotated, f"Cooldown {remaining:.0f}s", (10, 160),
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 165, 0), 1)
                else:
                    cv2.putText(annotated, f"Detecting... {FALL_CONFIRMATION_SECONDS - time_down:.1f}s",
                                (10, 160), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 165, 255), 2)
        else:
            if self.state.fall_start_time is not None:
                if self.state.fall_counted:
                    logger.info("✅ Person recovered from fall")
                self.state.fall_start_time = None
                self.state.fall_counted    = False

    # ── Inactivity Detection ──────────────────────────
    def _check_inactivity(self, landmarks, frame, annotated):
        h, w = frame.shape[:2]
        keypoints = np.array([
            [landmarks[15].x * w, landmarks[15].y * h],  # left wrist
            [landmarks[16].x * w, landmarks[16].y * h],  # right wrist
            [landmarks[11].x * w, landmarks[11].y * h],  # left shoulder
            [landmarks[12].x * w, landmarks[12].y * h],  # right shoulder
        ])

        if self.state.prev_keypoints is not None:
            movement = np.max(np.linalg.norm(keypoints - self.state.prev_keypoints, axis=1))
            if movement > INACTIVITY_MOVEMENT_PIXELS:
                self.state.last_movement_time = time.time()

        self.state.prev_keypoints = keypoints
        inactive_seconds = time.time() - self.state.last_movement_time

        if inactive_seconds >= INACTIVITY_THRESHOLD_SECONDS:
            self._draw_alert(annotated, f"INACTIVE {int(inactive_seconds)}s", (0, 165, 255))
            self.alert_sender.send_event("inactivity", INACTIVITY_CONFIDENCE, frame,
                                         self._extract_pose_data(landmarks, frame.shape))
            self.state.last_movement_time = time.time()

    # ── Sleeping Detection ────────────────────────────
    def _check_sleeping(self, landmarks, frame, annotated):
        from datetime import datetime
        hour = datetime.now().hour

        if self.wake_hour < self.sleep_hour:
            is_awake_time = self.wake_hour <= hour < self.sleep_hour
        else:
            is_awake_time = hour >= self.wake_hour or hour < self.sleep_hour

        if not is_awake_time:
            self.state.sleep_start_time = None
            return

        # Use same torso angle logic
        avg_shoulder_y = (landmarks[11].y + landmarks[12].y) / 2
        avg_hip_y      = (landmarks[23].y + landmarks[24].y) / 2
        shoulder_hip_diff = abs(avg_hip_y - avg_shoulder_y)
        is_lying = shoulder_hip_diff < SLEEP_ANGLE_THRESHOLD

        if is_lying:
            if self.state.sleep_start_time is None:
                self.state.sleep_start_time = time.time()
            elif time.time() - self.state.sleep_start_time >= SLEEP_CONFIRMATION_SECONDS:
                self._draw_alert(annotated, "SLEEPING DETECTED", (255, 0, 255))
                self.alert_sender.send_event("sleeping", SLEEP_CONFIDENCE, frame,
                                             self._extract_pose_data(landmarks, frame.shape))
                self.state.sleep_start_time = time.time()
        else:
            self.state.sleep_start_time = None

    # ── Helpers ───────────────────────────────────────
    def _draw_landmarks(self, frame, landmarks, shape):
        h, w = shape[:2]
        connections = [
            (11, 12), (11, 13), (13, 15), (12, 14), (14, 16),
            (11, 23), (12, 24), (23, 24),
            (23, 25), (25, 27), (24, 26), (26, 28),
        ]
        for lm in landmarks:
            cx, cy = int(lm.x * w), int(lm.y * h)
            cv2.circle(frame, (cx, cy), 4, (0, 255, 0), -1)
        for a, b in connections:
            if a < len(landmarks) and b < len(landmarks):
                ax, ay = int(landmarks[a].x * w), int(landmarks[a].y * h)
                bx, by = int(landmarks[b].x * w), int(landmarks[b].y * h)
                cv2.line(frame, (ax, ay), (bx, by), (0, 255, 0), 2)

    def _draw_alert(self, frame, text, color):
        cv2.putText(frame, text, (10, 60),
                    cv2.FONT_HERSHEY_SIMPLEX, 1.2, color, 3, cv2.LINE_AA)

    def _extract_pose_data(self, landmarks, shape):
        h, w = shape[:2]
        joints = {
            "NOSE": 0, "LEFT_SHOULDER": 11, "RIGHT_SHOULDER": 12,
            "LEFT_HIP": 23, "RIGHT_HIP": 24, "LEFT_KNEE": 25,
            "RIGHT_KNEE": 26, "LEFT_WRIST": 15, "RIGHT_WRIST": 16,
        }
        return {
            name: {
                "x":          round(landmarks[idx].x * w, 1),
                "y":          round(landmarks[idx].y * h, 1),
                "visibility": round(landmarks[idx].visibility, 2),
            }
            for name, idx in joints.items()
        }

    def close(self):
        self.detector.close()










