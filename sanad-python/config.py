# ─────────────────────────────────────────────
# SANAD Python AI Detection - Configuration
# DEMO MODE: Python + Docker + Simulator on same Mac
# ─────────────────────────────────────────────

SERVER_URL = "http://localhost:3000"

# Leave None → auto-fetched from DB on startup
ELDERLY_ID       = None
CAMERA_DEVICE_ID = None

# ─────────────────────────────────────────────
# TURN: DISABLED — all on same machine
# TURN routes through the internet and BREAKS
# same-laptop WebRTC. Keep None.
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
# Detection
# ─────────────────────────────────────────────
FALL_CONFIRMATION_SECONDS    = 1.5   # reduced from 2.0 — catch real falls faster
INACTIVITY_THRESHOLD_SECONDS = 30
INACTIVITY_MOVEMENT_PIXELS   = 15
SLEEP_ANGLE_THRESHOLD        = 0.15
SLEEP_CONFIRMATION_SECONDS   = 10
ALERT_COOLDOWN_SECONDS       = 60
FALL_CONFIDENCE              = 0.90
INACTIVITY_CONFIDENCE        = 0.85
SLEEP_CONFIDENCE             = 0.80