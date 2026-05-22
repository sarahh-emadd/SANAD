# ─────────────────────────────────────────────
# SANAD Python AI Detection - Configuration
# ─────────────────────────────────────────────

SERVER_URL = "http://localhost:3000"

# ── SET THIS — run to get the ID:
# docker exec graduation_project_db psql -U postgres -d sanad_pillbox \
#   -c "SELECT id, first_name FROM elderly;"
ELDERLY_ID       = None   # ← replace with "your-elderly-uuid"
CAMERA_DEVICE_ID = None   # leave None — auto-generated from MAC address

# ─────────────────────────────────────────────
# TURN (disabled — same-machine demo)
# ─────────────────────────────────────────────
TURN_HOST       = None
TURN_PORT       = 3478
TURN_USERNAME   = None
TURN_CREDENTIAL = None

# ─────────────────────────────────────────────
# Camera
# ─────────────────────────────────────────────
CAMERA_INDEX           = 0
FRAME_WIDTH            = 640
FRAME_HEIGHT           = 480
PROCESS_EVERY_N_FRAMES = 2

# ─────────────────────────────────────────────
# Fall Detection
# ─────────────────────────────────────────────
FALL_CONFIRMATION_SECONDS = 1.5   # seconds body must stay horizontal to confirm fall
FALL_CONFIDENCE           = 0.90
ALERT_COOLDOWN_SECONDS    = 60    # min gap between same-type alerts

# ─────────────────────────────────────────────
# Inactivity Detection  (tiered)
# ─────────────────────────────────────────────
INACTIVITY_THRESHOLD_SECONDS   = 30     # legacy keypoint threshold (kept for compat)
INACTIVITY_MOVEMENT_PIXELS     = 15     # keypoint movement px to reset timer
FRAME_DIFF_MOVEMENT_THRESHOLD  = 1000   # pixel-diff count to register as movement

INACTIVITY_WARNING_SECONDS     = 1800   # 30 min  → mild alert
INACTIVITY_CRITICAL_SECONDS    = 7200   # 2 hours → emergency alert
INACTIVITY_WARNING_CONFIDENCE  = 0.75
INACTIVITY_CRITICAL_CONFIDENCE = 0.90
INACTIVITY_CONFIDENCE          = 0.85   # default (used by legacy paths)
INACTIVITY_ALERT_COOLDOWN      = 900    # 15 min between repeated inactivity alerts

# ─────────────────────────────────────────────
# Night Restlessness Detection
# ─────────────────────────────────────────────
NIGHT_RESTLESSNESS_THRESHOLD  = 5000   # pixel-diff count = lots of movement
NIGHT_RESTLESSNESS_DURATION   = 120    # seconds of sustained movement to alert
NIGHT_RESTLESSNESS_CONFIDENCE = 0.80

# ─────────────────────────────────────────────
# Sleeping Detection
# ─────────────────────────────────────────────
SLEEP_ANGLE_THRESHOLD        = 0.15
SLEEP_CONFIRMATION_SECONDS   = 10
SLEEP_CONFIDENCE             = 0.80
