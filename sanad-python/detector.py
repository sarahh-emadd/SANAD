import time
import logging
import collections
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
    INACTIVITY_WARNING_SECONDS, INACTIVITY_CRITICAL_SECONDS,
    FRAME_DIFF_MOVEMENT_THRESHOLD,
    NIGHT_RESTLESSNESS_THRESHOLD, NIGHT_RESTLESSNESS_DURATION,
    INACTIVITY_WARNING_CONFIDENCE, INACTIVITY_CRITICAL_CONFIDENCE,
    NIGHT_RESTLESSNESS_CONFIDENCE, INACTIVITY_ALERT_COOLDOWN,
)
from schedule import fetch_sleep_schedule

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────
# Fall Detection Algorithm (velocity-aware)
#
# Key insight: a FALL is fast (body goes from
# vertical → horizontal in < 1.5 s). Sleeping
# is slow. We track posture history to measure
# the transition speed and distinguish the two.
#
# Rules (weights):
#   Rule 1: Torso horizontal     45%
#   Rule 2: Legs collapsed       30%
#   Rule 3: Head at torso level  15%
#   Rule 4: Fast transition      10% bonus
# Threshold: 65% (lower than default to catch real falls)
# ─────────────────────────────────────────────
def analyze_fall(landmarks, posture_history=None):
    """
    posture_history: collections.deque of (timestamp, shoulder_hip_diff)
                     — pass None when history is unavailable.
    Returns (is_fall, confidence, reason_str)
    """
    if not landmarks or len(landmarks) < 33:
        return False, 0.0, "Incomplete landmarks"

    nose           = landmarks[0]
    left_shoulder  = landmarks[11]
    right_shoulder = landmarks[12]
    left_hip       = landmarks[23]
    right_hip      = landmarks[24]
    left_knee      = landmarks[25]
    right_knee     = landmarks[26]
    left_ankle     = landmarks[27]
    right_ankle    = landmarks[28]

    avg_hip_y      = (left_hip.y      + right_hip.y)      / 2
    avg_shoulder_y = (left_shoulder.y + right_shoulder.y) / 2
    avg_knee_y     = (left_knee.y     + right_knee.y)     / 2
    avg_ankle_y    = (left_ankle.y    + right_ankle.y)    / 2

    shoulder_hip_diff = abs(avg_hip_y - avg_shoulder_y)

    confidence = 0.0
    reasons    = []

    # Rule 1: Torso horizontal (45%)
    if shoulder_hip_diff < 0.15:
        confidence += 0.45
        reasons.append("Torso horizontal")
    elif shoulder_hip_diff < 0.25:
        confidence += 0.22
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

    # Rule 3: Head at torso level (15%, only if nose visible)
    nose_hip_diff = avg_hip_y - nose.y
    nose_valid    = abs(nose_hip_diff) >= 0.02
    if nose_valid and nose_hip_diff >= 0:
        if nose_hip_diff < 0.08:
            confidence += 0.15
            reasons.append("Head at torso level")
        elif nose_hip_diff < 0.15:
            confidence += 0.07
    elif not nose_valid:
        reasons.append("Face covered")

    # Rule 4: Velocity bonus — fast transition = fall, slow = sleep (10%)
    # Look back up to 1.5 seconds. If body went from vertical (diff > 0.30)
    # to horizontal (diff < 0.20) quickly, boost confidence.
    if posture_history and len(posture_history) >= 3:
        now = time.time()
        # Find the most upright posture within the last 2 seconds
        recent = [(t, d) for t, d in posture_history if now - t <= 2.0]
        if recent:
            max_diff_recent = max(d for _, d in recent)
            # Was person upright recently and now horizontal?
            if max_diff_recent > 0.28 and shoulder_hip_diff < 0.20:
                # How fast? time from upright to now
                upright_time = next(
                    (t for t, d in reversed(list(recent)) if d > 0.28), None
                )
                if upright_time and (now - upright_time) < 1.5:
                    confidence += 0.10
                    reasons.append(f"Fast drop {now - upright_time:.1f}s")
                elif upright_time and (now - upright_time) < 3.0:
                    confidence += 0.05
                    reasons.append("Moderate drop")
            # Slow transition (sleep-like): penalise slightly
            elif max_diff_recent > 0.28 and shoulder_hip_diff < 0.20:
                confidence -= 0.05  # gradual lie-down → less likely a fall

    confidence = max(0.0, min(confidence, 1.0))
    is_fall    = confidence >= 0.65   # slightly lower than 0.70 to catch real falls
    reason_str = ", ".join(reasons) if reasons else "Normal posture"

    return is_fall, confidence, reason_str


# ─────────────────────────────────────────────
# Movement / Activity Tracking (standalone)
# ─────────────────────────────────────────────
def detect_inactivity(current_frame, previous_frame, time_inactive):
    """
    Frame-difference inactivity check with tiered thresholds.
    Returns (is_alert, confidence, reason).
    """
    diff = cv2.absdiff(current_frame, previous_frame)
    movement_pixels = int(np.sum(diff > 30))

    if movement_pixels < FRAME_DIFF_MOVEMENT_THRESHOLD:
        if time_inactive > INACTIVITY_CRITICAL_SECONDS:
            return True, INACTIVITY_CRITICAL_CONFIDENCE, "No movement for 2+ hours"
        elif time_inactive > INACTIVITY_WARNING_SECONDS:
            return True, INACTIVITY_WARNING_CONFIDENCE, "Extended inactivity"

    return False, 0.0, "Active"


# ─────────────────────────────────────────────
# Detection State
# ─────────────────────────────────────────────
class DetectionState:
    def __init__(self):
        # Fall
        self.fall_start_time  = None
        self.fall_counted     = False
        self.last_fall_time   = 0

        # Posture history: deque of (timestamp, shoulder_hip_diff)
        # Used by analyze_fall to compute transition velocity.
        self.posture_history = collections.deque(maxlen=60)  # ~2 s at 30 fps

        # Inactivity (keypoint-based)
        self.last_movement_time = time.time()
        self.prev_keypoints     = None

        # Activity tracking (frame-diff tiered alerts)
        self.prev_frame                    = None
        self.last_inactivity_warning_time  = 0
        self.last_inactivity_critical_time = 0

        # Night restlessness
        self.night_restlessness_start     = None
        self.last_restlessness_alert_time = 0

        # Sleeping
        self.sleep_start_time = None


# ─────────────────────────────────────────────
# Detector
# ─────────────────────────────────────────────
class Detector:
    def __init__(self, alert_sender):
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

        schedule        = fetch_sleep_schedule()
        self.wake_hour  = schedule["wake_hour"]
        self.sleep_hour = schedule["sleep_hour"]

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
            self._check_inactivity(None, frame, annotated)  # frame-diff works without pose
            cv2.putText(annotated, "No person detected", (10, 50),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)

        # Night restlessness runs always (independent of pose detection)
        self._check_night_restlessness(frame, annotated)

        # Save frame for next iteration's frame-diff calculations
        self.state.prev_frame = frame.copy()

        return annotated, pose_data

    # ── Fall Detection ────────────────────────────────
    def _check_fall(self, landmarks, frame, annotated):
        # Record current posture angle for velocity tracking
        avg_sh_y = (landmarks[11].y + landmarks[12].y) / 2
        avg_hp_y = (landmarks[23].y + landmarks[24].y) / 2
        self.state.posture_history.append((time.time(), abs(avg_hp_y - avg_sh_y)))

        is_fall, confidence, reason = analyze_fall(landmarks, self.state.posture_history)

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
                        self.state.fall_counted   = True
                        self.state.last_fall_time = current_time
                        self._draw_alert(annotated, "FALL DETECTED", (0, 0, 255))
                        self.alert_sender.send_event("fall", confidence, frame,
                                                     self._extract_pose_data(landmarks, frame.shape))
                        logger.warning(f"🚨 Fall confirmed — conf: {confidence:.0%}")
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

    # ── Inactivity / Activity Detection ──────────────
    def _check_inactivity(self, landmarks, frame, annotated):
        current_time = time.time()
        h, w = frame.shape[:2]

        # ── Keypoint-based movement detection (requires pose) ──
        if landmarks is not None:
            keypoints = np.array([
                [landmarks[15].x * w, landmarks[15].y * h],  # left wrist
                [landmarks[16].x * w, landmarks[16].y * h],  # right wrist
                [landmarks[11].x * w, landmarks[11].y * h],  # left shoulder
                [landmarks[12].x * w, landmarks[12].y * h],  # right shoulder
            ])
            if self.state.prev_keypoints is not None:
                movement = np.max(np.linalg.norm(keypoints - self.state.prev_keypoints, axis=1))
                if movement > INACTIVITY_MOVEMENT_PIXELS:
                    self.state.last_movement_time = current_time
            self.state.prev_keypoints = keypoints

        # ── Frame-difference movement detection (works without pose) ──
        if self.state.prev_frame is not None:
            diff = cv2.absdiff(frame, self.state.prev_frame)
            if int(np.sum(diff > 30)) >= FRAME_DIFF_MOVEMENT_THRESHOLD:
                self.state.last_movement_time = current_time

        inactive_seconds = current_time - self.state.last_movement_time

        # ── Tiered alert via detect_inactivity ──
        if self.state.prev_frame is not None:
            is_alert, confidence, reason = detect_inactivity(
                frame, self.state.prev_frame, inactive_seconds
            )
            if is_alert:
                pose_data = (self._extract_pose_data(landmarks, frame.shape)
                             if landmarks is not None else None)
                if confidence >= INACTIVITY_CRITICAL_CONFIDENCE:
                    if (current_time - self.state.last_inactivity_critical_time) > INACTIVITY_ALERT_COOLDOWN:
                        self._draw_alert(annotated, "NO MOVEMENT 2+ HOURS", (0, 0, 255))
                        self.alert_sender.send_event("inactivity", confidence, frame, pose_data)
                        self.state.last_inactivity_critical_time = current_time
                        logger.warning(f"🚨 Critical inactivity: {reason}")
                else:
                    if (current_time - self.state.last_inactivity_warning_time) > INACTIVITY_ALERT_COOLDOWN:
                        self._draw_alert(annotated, "EXTENDED INACTIVITY", (0, 165, 255))
                        self.alert_sender.send_event("inactivity", confidence, frame, pose_data)
                        self.state.last_inactivity_warning_time = current_time
                        logger.warning(f"⚠️  Inactivity warning: {reason}")

        # ── Display inactive duration on frame when notable ──
        if inactive_seconds >= 300:
            mins = int(inactive_seconds // 60)
            label = (f"Inactive: {mins}m" if mins < 60
                     else f"Inactive: {mins // 60}h {mins % 60}m")
            cv2.putText(annotated, label, (10, 200),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 165, 0), 2)

    # ── Night Restlessness Detection ─────────────────
    def _check_night_restlessness(self, frame, annotated):
        from datetime import datetime
        hour = datetime.now().hour

        # Determine if it is currently sleep time
        if self.wake_hour < self.sleep_hour:
            is_sleep_time = not (self.wake_hour <= hour < self.sleep_hour)
        else:
            is_sleep_time = not (hour >= self.wake_hour or hour < self.sleep_hour)

        if not is_sleep_time or self.state.prev_frame is None:
            self.state.night_restlessness_start = None
            return

        diff = cv2.absdiff(frame, self.state.prev_frame)
        movement_pixels = int(np.sum(diff > 30))
        current_time = time.time()

        if movement_pixels > NIGHT_RESTLESSNESS_THRESHOLD:
            if self.state.night_restlessness_start is None:
                self.state.night_restlessness_start = current_time
                logger.debug("🌙 Night movement started")
            elif (current_time - self.state.night_restlessness_start) >= NIGHT_RESTLESSNESS_DURATION:
                if (current_time - self.state.last_restlessness_alert_time) > ALERT_COOLDOWN_SECONDS:
                    self._draw_alert(annotated, "NIGHT RESTLESSNESS", (255, 165, 0))
                    self.alert_sender.send_event(
                        "night_restlessness", NIGHT_RESTLESSNESS_CONFIDENCE, frame, None
                    )
                    self.state.last_restlessness_alert_time = current_time
                    self.state.night_restlessness_start     = None
                    logger.warning("🌙 Night restlessness detected and alert sent")
        else:
            self.state.night_restlessness_start = None

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

        # Skip sleeping check if a fall was just confirmed (within 90 s).
        # A person who fell and stays on the ground must NOT be re-labelled
        # as "sleeping" — the fall alert already covers it.
        if (time.time() - self.state.last_fall_time) < 90:
            self.state.sleep_start_time = None
            return

        avg_shoulder_y    = (landmarks[11].y + landmarks[12].y) / 2
        avg_hip_y         = (landmarks[23].y + landmarks[24].y) / 2
        shoulder_hip_diff = abs(avg_hip_y - avg_shoulder_y)
        is_lying = shoulder_hip_diff < SLEEP_ANGLE_THRESHOLD

        # Velocity check: if posture history shows a fast drop, it was a fall, not sleep
        slow_transition = True
        if self.state.posture_history and len(self.state.posture_history) >= 5:
            now    = time.time()
            recent = [(t, d) for t, d in self.state.posture_history if now - t <= 1.5]
            if recent:
                max_recent = max(d for _, d in recent)
                if max_recent > 0.28 and shoulder_hip_diff < 0.20:
                    # Person was upright and quickly went horizontal — that's a fall
                    slow_transition = False

        if is_lying and slow_transition:
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
