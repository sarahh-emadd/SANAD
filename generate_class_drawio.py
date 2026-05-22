#!/usr/bin/env python3
"""Generate SANAD Class Diagram as draw.io XML — run once to regenerate."""

import xml.etree.ElementTree as ET
from xml.dom import minidom

_id = [2]
def nid():
    i = _id[0]; _id[0] += 1; return str(i)

ROW_H   = 20
HEAD_H  = 30
COL_W   = 252
GAP     = 14

# Column x positions
X_DB      = 20
X_PILL    = X_DB   + COL_W + GAP
X_SVC     = X_PILL + COL_W + GAP
X_CTRL    = X_SVC  + COL_W + GAP
X_PY      = X_CTRL + COL_W + GAP
X_FL      = X_PY   + COL_W + GAP

# Per-layer colours  (fill, stroke)
C_DB    = ("#dae8fc", "#006EAF")
C_PILL  = ("#d5e8d4", "#82b366")
C_SVC   = ("#fff2cc", "#d6b656")
C_CTRL  = ("#ffe6cc", "#d79b00")
C_PY    = ("#f8cecc", "#b85450")
C_FL    = ("#e1d5e7", "#9673a6")

def cls(root, name, fields, methods, x, y, fill, stroke, w=COL_W):
    fh = len(fields)  * ROW_H
    mh = len(methods) * ROW_H
    sep = 6 if methods else 0
    total = HEAD_H + fh + sep + mh + 4

    cid = nid()
    c = ET.SubElement(root, "mxCell", {
        "id": cid, "value": name,
        "style": (f"swimlane;startSize={HEAD_H};fontStyle=1;fontSize=11;"
                  f"align=center;fillColor={fill};strokeColor={stroke};"
                  f"fontColor=#000000;"),
        "vertex": "1", "parent": "1"
    })
    ET.SubElement(c, "mxGeometry", {
        "x": str(x), "y": str(y), "width": str(w), "height": str(total),
        "as": "geometry"
    })

    fs = ("text;strokeColor=none;fillColor=none;align=left;"
          "verticalAlign=middle;spacingLeft=6;overflow=hidden;"
          "rotatable=0;fontSize=10;")
    ms = fs + "fontStyle=2;"

    cy = HEAD_H
    for f in fields:
        fc = ET.SubElement(root, "mxCell", {
            "id": nid(), "value": f, "style": fs,
            "vertex": "1", "parent": cid
        })
        ET.SubElement(fc, "mxGeometry", {
            "y": str(cy), "width": str(w), "height": str(ROW_H), "as": "geometry"
        })
        cy += ROW_H

    if methods:
        sc = ET.SubElement(root, "mxCell", {
            "id": nid(), "value": "",
            "style": f"line;strokeColor={stroke};fillColor=none;",
            "vertex": "1", "parent": cid
        })
        ET.SubElement(sc, "mxGeometry", {
            "y": str(cy), "width": str(w), "height": str(sep), "as": "geometry"
        })
        cy += sep
        for m in methods:
            mc = ET.SubElement(root, "mxCell", {
                "id": nid(), "value": m, "style": ms,
                "vertex": "1", "parent": cid
            })
            ET.SubElement(mc, "mxGeometry", {
                "y": str(cy), "width": str(w), "height": str(ROW_H),
                "as": "geometry"
            })
            cy += ROW_H

    return cid, total

def rel(root, src, tgt, label="", style="dep"):
    styles = {
        "dep":   "endArrow=open;endFill=0;dashed=1;strokeColor=#555555;fontSize=9;",
        "assoc": "endArrow=open;endFill=0;strokeColor=#555555;fontSize=9;",
        "comp":  "endArrow=ERmany;endFill=1;strokeColor=#555555;startArrow=ERmandOne;startFill=1;fontSize=9;",
    }
    ec = ET.SubElement(root, "mxCell", {
        "id": nid(), "value": label,
        "style": styles.get(style, styles["dep"]),
        "edge": "1", "source": src, "target": tgt, "parent": "1"
    })
    ET.SubElement(ec, "mxGeometry", {"relative": "1", "as": "geometry"})

# ── Build graph ─────────────────────────────────────────────────────────────
mxfile  = ET.Element("mxfile", {"host": "app.diagrams.net"})
diagram = ET.SubElement(mxfile, "diagram", {"name": "SANAD Class Diagram"})
model   = ET.SubElement(diagram, "mxGraphModel", {
    "dx": "1422", "dy": "762", "grid": "1", "gridSize": "10",
    "guides": "1", "tooltips": "1", "connect": "1", "arrows": "1",
    "fold": "1", "page": "1", "pageScale": "1",
    "pageWidth": "1654", "pageHeight": "1169", "math": "0", "shadow": "0"
})
root = ET.SubElement(model, "root")
ET.SubElement(root, "mxCell", {"id": "0"})
ET.SubElement(root, "mxCell", {"id": "1", "parent": "0"})

ids = {}
def C(name, fields, methods, x, y, color):
    cid, h = cls(root, name, fields, methods, x, y, *color)
    ids[name] = cid
    return h

# ═══════════════════════════════════════════════════════
# COLUMN 1 — Database Core
# ═══════════════════════════════════════════════════════
y = 20
y += C("Caregiver", [
    "+ id : UUID  [PK]",
    "+ firebase_uid : String",
    "+ email : String",
    "+ first_name : String",
    "+ last_name : String",
    "+ phone : String",
    "+ fcm_token : String",
    "+ status : String",
    "+ created_at : Timestamp",
], [], X_DB, y, C_DB) + GAP

y += C("Elderly", [
    "+ id : UUID  [PK]",
    "+ caregiver_id : UUID  [FK]",
    "+ first_name : String",
    "+ last_name : String",
    "+ date_of_birth : Date",
    "+ gender : String",
    "+ blood_type : String",
    "+ medical_conditions : String",
    "+ allergies : String",
    "+ mobility_level : String",
    "+ typical_sleep_time : Time",
    "+ typical_wake_time : Time",
    "+ is_connected : Boolean",
    "+ status : String",
], [], X_DB, y, C_DB) + GAP

y += C("Event", [
    "+ id : UUID  [PK]",
    "+ elderly_id : UUID  [FK]",
    "+ event_type : String",
    "    fall | inactivity | sleeping",
    "    night_restlessness",
    "+ confidence : Double",
    "+ snapshot_url : String",
    "+ pose_data : JSONB",
    "+ verified : Boolean",
    "+ is_false_positive : Boolean",
    "+ alert_sent : Boolean",
    "+ created_at : Timestamp",
], [], X_DB, y, C_DB) + GAP

y += C("SosRequest", [
    "+ id : UUID  [PK]",
    "+ elderly_id : UUID  [FK]",
    "+ caregiver_id : UUID  [FK]",
    "+ status : String",
    "+ source : String  (manual|auto_fall)",
    "+ created_at : Timestamp",
    "+ acknowledged_at : Timestamp",
], [], X_DB, y, C_DB) + GAP

y += C("Camera", [
    "+ id : UUID  [PK]",
    "+ camera_device_id : String",
    "+ elderly_id : UUID  [FK]",
    "+ status : String",
    "+ updated_at : Timestamp",
], [], X_DB, y, C_DB) + GAP

y += C("ElderLocation", [
    "+ elderly_id : UUID  [FK]",
    "+ latitude : Double",
    "+ longitude : Double",
    "+ address : String",
    "+ is_home : Boolean",
    "+ battery_level : Integer",
    "+ last_seen : Timestamp",
    "+ updated_at : Timestamp",
], [], X_DB, y, C_DB) + GAP

y += C("ElderSafeZone", [
    "+ id : UUID  [PK]",
    "+ elderly_id : UUID  [FK]",
    "+ center_lat : Double",
    "+ center_lng : Double",
    "+ radius_meters : Integer",
    "+ is_active : Boolean",
    "+ last_alerted_at : Timestamp",
], [], X_DB, y, C_DB) + GAP

C("VoiceMessage", [
    "+ id : UUID  [PK]",
    "+ caregiver_id : UUID  [FK]",
    "+ elderly_id : UUID  [FK]",
    "+ title : String",
    "+ file_path : String",
    "+ duration_secs : Integer",
    "+ used_times : Integer",
    "+ is_saved : Boolean",
    "+ created_at : Timestamp",
], [], X_DB, y, C_DB)

# ═══════════════════════════════════════════════════════
# COLUMN 2 — Pillbox Tables + QR/Connection
# ═══════════════════════════════════════════════════════
y = 20
y += C("PillSlot", [
    "+ id : UUID  [PK]",
    "+ elderly_id : UUID  [FK]",
    "+ slot_number : Integer  (1-3)",
    "+ medication_name : String",
    "+ notes : String",
    "+ is_active : Boolean",
    "+ created_at : Timestamp",
    "+ updated_at : Timestamp",
], [], X_PILL, y, C_PILL) + GAP

y += C("PillSchedule", [
    "+ id : UUID  [PK]",
    "+ slot_id : UUID  [FK]",
    "+ elderly_id : UUID  [FK]",
    "+ scheduled_time : Time",
    "+ days_of_week : Integer[]",
    "+ is_active : Boolean",
    "+ created_at : Timestamp",
], [], X_PILL, y, C_PILL) + GAP

y += C("PillLog", [
    "+ id : UUID  [PK]",
    "+ schedule_id : UUID  [FK]",
    "+ elderly_id : UUID  [FK]",
    "+ status : String",
    "    taken | missed | pending",
    "+ taken_at : Timestamp",
    "+ notified : Boolean",
    "+ created_at : Timestamp",
], [], X_PILL, y, C_PILL) + GAP

y += C("PillboxDevice", [
    "+ id : UUID  [PK]",
    "+ elderly_id : UUID  [FK]",
    "+ mac_address : String",
    "+ last_seen : Timestamp",
    "+ created_at : Timestamp",
], [], X_PILL, y, C_PILL) + GAP

y += C("QrToken", [
    "+ id : UUID  [PK]",
    "+ elderly_id : UUID  [FK]",
    "+ token : String",
    "+ manual_code : String  (6 digits)",
    "+ expires_at : Timestamp",
    "+ is_active : Boolean",
    "+ used_at : Timestamp",
    "+ revoked_at : Timestamp",
], [], X_PILL, y, C_DB) + GAP

C("ElderlyConnection", [
    "+ id : UUID  [PK]",
    "+ elderly_id : UUID  [FK]",
    "+ qr_token_id : UUID  [FK]",
    "+ connected_at : Timestamp",
    "+ disconnected_at : Timestamp",
    "+ disconnection_reason : String",
], [], X_PILL, y, C_DB)

# ═══════════════════════════════════════════════════════
# COLUMN 3 — Backend Services
# ═══════════════════════════════════════════════════════
y = 20
y += C("AuthService", [], [
    "+ syncUser(uid, email, name) : Caregiver",
    "+ getCaregiverByUid(uid) : Caregiver",
    "+ updateFcmToken(id, token) : void",
    "+ updateProfile(id, data) : Caregiver",
    "+ deleteAccount(id) : void",
], X_SVC, y, C_SVC) + GAP

y += C("ElderlyService", [], [
    "+ create(caregiverId, data) : Elderly",
    "+ getAll(caregiverId) : Elderly[]",
    "+ getById(elderlyId) : Elderly",
    "+ update(elderlyId, data) : Elderly",
    "+ delete(elderlyId) : void",
    "+ disconnectDevice(elderlyId) : void",
    "+ getStats(caregiverId) : Object",
], X_SVC, y, C_SVC) + GAP

y += C("EventsService", [], [
    "+ createEvent(elderlyId, data) : Event",
    "+ getEventsByElderly(id) : Event[]",
    "+ getUnverifiedEvents(cgId) : Event[]",
    "+ verifyEvent(id, cgId, fp) : Event",
    "+ markAlertSent(eventId) : void",
    "+ getTodayStats(elderlyId) : Object",
    "    {fall, inactivity, sleeping,",
    "     night_restlessness, total}",
], X_SVC, y, C_SVC) + GAP

y += C("SosService", [], [
    "+ createSos(elderlyId, source) : Sos",
    "+ acknowledgeSos(sosId) : Sos",
    "+ getSosHistory(caregiverId) : Sos[]",
], X_SVC, y, C_SVC) + GAP

y += C("NotificationService", [], [
    "+ sendEventAlert(id, type, conf)",
    "+ sendSosAlert(id, sosId, source)",
    "+ sendGeofenceAlert(id, distMeters)",
    "+ sendBatteryAlert(id, level)",
    "+ sendRawNotification(token, msg)",
], X_SVC, y, C_SVC) + GAP

y += C("MinioService", [], [
    "+ uploadSnapshot(id, buf, type) : url",
    "+ getSignedUrl(objectName) : url",
    "+ deleteFile(objectName) : void",
], X_SVC, y, C_SVC) + GAP

y += C("SocketService", [], [
    "+ initializeSocket(server) : void",
    "+ emitAlert(io, cgId, data) : void",
    "+ emitSosAlert(io, cgId, data) : void",
], X_SVC, y, C_SVC) + GAP

C("PillboxService", [], [
    "+ getSlots(elderlyId) : PillSlot[]",
    "+ updateSlot(id, slotNo, data)",
    "+ addSchedule(slotId, data)",
    "+ updateSchedule(id, data)",
    "+ deleteSchedule(id)",
    "+ getTodaySchedule(elderlyId)",
    "+ upsertLog(schedId, status)",
    "+ markNotified(schedId, date)",
    "+ getLogs(elderlyId) : PillLog[]",
    "+ registerDevice(mac, elderlyId)",
    "+ getElderlyByMac(mac) : Object",
    "+ getCaregiverFcm(elderlyId) : String",
], X_SVC, y, C_PILL)

# ═══════════════════════════════════════════════════════
# COLUMN 4 — Backend Controllers
# ═══════════════════════════════════════════════════════
y = 20
y += C("AuthController", [], [
    "+ syncUser(req, res)",
    "+ getMe(req, res)",
    "+ updateProfile(req, res)",
    "+ updateFcmToken(req, res)",
    "+ deleteAccount(req, res)",
    "+ checkEmail(req, res)",
], X_CTRL, y, C_CTRL) + GAP

y += C("ElderlyController", [], [
    "+ create(req, res)",
    "+ getAll(req, res)",
    "+ getById(req, res)",
    "+ getWithQR(req, res)",
    "+ update(req, res)",
    "+ deleteElderly(req, res)",
    "+ disconnectDevice(req, res)",
    "+ regenerateQR(req, res)",
    "+ getStats(req, res)",
], X_CTRL, y, C_CTRL) + GAP

y += C("EventsController", [], [
    "+ createEvent(req, res)",
    "    allowed types:",
    "    fall|inactivity|sleeping",
    "    night_restlessness",
    "+ getEventsByElderly(req, res)",
    "+ getUnverifiedEvents(req, res)",
    "+ verifyEvent(req, res)",
    "+ getNotifications(req, res)",
    "+ getTodayStats(req, res)",
], X_CTRL, y, C_CTRL) + GAP

y += C("SosController", [], [
    "+ triggerSos(req, res)",
    "+ acknowledgeSos(req, res)",
    "+ getSosHistory(req, res)",
], X_CTRL, y, C_CTRL) + GAP

y += C("QrController", [], [
    "+ connectByQR(req, res)",
    "+ connectByManual(req, res)",
    "+ verifyQR(req, res)",
], X_CTRL, y, C_CTRL) + GAP

C("PillboxController", [], [
    "── Caregiver routes (auth required) ──",
    "+ getSlots(req, res)",
    "+ updateSlot(req, res)",
    "+ addSchedule(req, res)",
    "+ updateSchedule(req, res)",
    "+ deleteSchedule(req, res)",
    "+ getLogs(req, res)",
    "+ getTodaySchedule(req, res)",
    "── ESP32 routes (no auth) ──",
    "+ registerDevice(req, res)",
    "+ getDeviceSchedule(req, res)",
    "+ reportDose(req, res)",
], X_CTRL, y, C_PILL)

# ═══════════════════════════════════════════════════════
# COLUMN 5 — Python AI
# ═══════════════════════════════════════════════════════
y = 20
y += C("Detector", [
    "─── attributes ───",
    "- detector : PoseLandmarker",
    "- alert_sender : AlertSender",
    "- state : DetectionState",
    "- timestamp_ms : int",
    "- wake_hour : int",
    "- sleep_hour : int",
], [
    "─── methods ───",
    "+ process_frame(frame) : annotated",
    "+ _check_fall(landmarks, frame)",
    "+ _check_inactivity(landmarks, frame)",
    "+ _check_sleeping(landmarks, frame)",
    "+ _check_night_restlessness(frame)",
    "+ close() : void",
], X_PY, y, C_PY) + GAP

y += C("DetectionState", [
    "+ fall_start_time : float",
    "+ fall_counted : bool",
    "+ last_fall_time : float",
    "+ posture_history : deque(maxlen=60)",
    "+ last_movement_time : float",
    "+ prev_keypoints : ndarray",
    "+ prev_frame : ndarray",
    "+ last_inactivity_warning_time : float",
    "+ last_inactivity_critical_time : float",
    "+ night_restlessness_start : float",
    "+ last_restlessness_alert_time : float",
    "+ sleep_start_time : float",
], [], X_PY, y, C_PY) + GAP

y += C("analyze_fall()", [
    "─── velocity-aware fall detection ───",
    "Rule 1: Torso horizontal  (45%)",
    "Rule 2: Legs collapsed    (30%)",
    "Rule 3: Head at torso lvl (15%)",
    "Rule 4: Fast drop bonus   (10%)",
    "Threshold: 0.65",
    "posture_history: deque for velocity",
], [], X_PY, y, C_PY) + GAP

y += C("detect_inactivity()", [
    "─── tiered frame-diff check ───",
    "frame-diff pixel count > 30",
    "if < FRAME_DIFF_THRESHOLD:",
    "  >30 min → warning (0.75 conf)",
    "  >2 hrs  → critical (0.90 conf)",
    "Returns (is_alert, conf, reason)",
], [], X_PY, y, C_PY) + GAP

y += C("AlertSender", [
    "- server_url : String",
    "- elderly_id : String",
    "- camera_device_id : String",
], [
    "+ send_event(type, conf, frame, pose)",
    "+ fetch_elderly_id(cam_device_id)",
], X_PY, y, C_PY) + GAP

y += C("WebRTCStreamer", [
    "- pc : RTCPeerConnection",
    "- socket : SocketIO",
    "- frame_queue : Queue",
], [
    "+ connect(elderly_id, cg_id)",
    "+ send_frame(frame)",
    "+ disconnect()",
], X_PY, y, C_PY) + GAP

C("Config", [
    "+ SERVER_URL : String",
    "+ ELDERLY_ID : String  (auto-polled)",
    "+ FALL_CONFIRMATION_SECONDS : 1.5",
    "+ INACTIVITY_WARNING_SECONDS : 1800",
    "+ INACTIVITY_CRITICAL_SECONDS : 7200",
    "+ INACTIVITY_ALERT_COOLDOWN : 900",
    "+ FRAME_DIFF_MOVEMENT_THRESHOLD : 1000",
    "+ NIGHT_RESTLESSNESS_THRESHOLD : 5000",
    "+ NIGHT_RESTLESSNESS_DURATION : 120",
    "+ FALL_CONFIDENCE : 0.90",
    "+ INACTIVITY_WARNING_CONFIDENCE : 0.75",
    "+ INACTIVITY_CRITICAL_CONFIDENCE : 0.90",
    "+ NIGHT_RESTLESSNESS_CONFIDENCE : 0.80",
    "+ SLEEP_CONFIDENCE : 0.80",
    "+ ALERT_COOLDOWN_SECONDS : 60",
], [], X_PY, y, C_PY)

# ═══════════════════════════════════════════════════════
# COLUMN 6 — Flutter
# ═══════════════════════════════════════════════════════
y = 20
y += C("ElderlyModel", [
    "+ id : String",
    "+ caregiverId : String",
    "+ firstName : String",
    "+ lastName : String",
    "+ dateOfBirth : DateTime",
    "+ medicalConditions : String",
    "+ mobilityLevel : String",
    "+ typicalSleepTime : String",
    "+ typicalWakeTime : String",
    "+ isConnected : bool",
], [
    "+ get fullName() : String",
    "+ fromJson(json) : ElderlyModel",
    "+ toRequestBody() : Map",
], X_FL, y, C_FL) + GAP

y += C("EventModel", [
    "+ id : String",
    "+ elderlyId : String",
    "+ elderlyName : String",
    "+ eventType : String",
    "+ confidence : double",
    "+ snapshotUrl : String?",
    "+ verified : bool",
    "+ isFalsePositive : bool",
    "+ createdAt : DateTime",
], [
    "+ get title() : String",
    "  fall | inactivity | sleeping",
    "  night_restlessness",
    "+ get confidencePercent() : String",
    "+ get timeAgo() : String",
    "+ fromJson(json) : EventModel",
], X_FL, y, C_FL) + GAP

y += C("TodayStats", [
    "+ falls : int",
    "+ inactivity : int",
    "+ sleeping : int",
    "+ nightRestlessness : int",
    "+ total : int",
], [
    "+ get activityLevel() : String",
    "  Normal | Danger | Low Activity",
    "  Restless Night 🌙 | Sleeping 💤",
], X_FL, y, C_FL) + GAP

y += C("QrModel", [
    "+ id : String",
    "+ elderlyId : String",
    "+ token : String",
    "+ manualCode : String  (6 digits)",
    "+ isActive : bool",
    "+ expiresAt : DateTime",
], [
    "+ get isValid() : bool",
    "+ get remainingMinutes() : int",
    "+ fromJson(json) : QrModel",
], X_FL, y, C_FL) + GAP

y += C("LocationModel", [
    "+ latitude : double",
    "+ longitude : double",
    "+ address : String",
    "+ lastUpdated : DateTime",
    "+ isHome : bool",
    "+ batteryLevel : int",
], [
    "+ get lastSeenLabel() : String",
    "+ fromJson(json) : LocationModel",
    "+ toJson() : Map",
], X_FL, y, C_FL) + GAP

y += C("WebRTCService  (Flutter)", [
    "- caregiverId : String",
    "- elderlyId : String",
    "- onConnected : Function",
    "- onDisconnected : Function",
    "- onAlert : Function",
    "- onCameraOffline : Function",
], [
    "+ connect()",
    "+ disconnect()",
    "+ createOffer() : Map",
    "+ handleAnswer(answer)",
    "+ addIceCandidate(candidate)",
], X_FL, y, C_FL) + GAP

y += C("LocationService  (Flutter)", [], [
    "+ reportLocation(elderlyId) : bool",
    "+ startPeriodicReporting()",
    "+ stopReporting()",
], X_FL, y, C_FL) + GAP

y += C("SosService  (Flutter)", [], [
    "+ triggerSos(elderlyId) : Map",
    "+ acknowledgeSos(sosId) : void",
    "+ getSosHistory() : List",
], X_FL, y, C_FL) + GAP

C("VoiceReminderService", [], [
    "+ getReminders(elderlyId) : List",
    "+ createReminder(id, title, path)",
    "+ sendReminder(reminderId, eldId)",
    "+ deleteReminder(reminderId)",
], X_FL, y, C_FL)

# ═══════════════════════════════════════════════════════
# RELATIONSHIPS
# ═══════════════════════════════════════════════════════
# DB
rel(root, ids["Caregiver"],        ids["Elderly"],          "owns",       "assoc")
rel(root, ids["Elderly"],          ids["Event"],            "generates",  "comp")
rel(root, ids["Elderly"],          ids["SosRequest"],       "triggers",   "comp")
rel(root, ids["Elderly"],          ids["Camera"],           "monitored",  "assoc")
rel(root, ids["Elderly"],          ids["ElderLocation"],    "has",        "comp")
rel(root, ids["Elderly"],          ids["ElderSafeZone"],    "has",        "comp")
rel(root, ids["Elderly"],          ids["PillSlot"],         "has 3",      "comp")
rel(root, ids["PillSlot"],         ids["PillSchedule"],     "schedules",  "comp")
rel(root, ids["PillSchedule"],     ids["PillLog"],          "logs",       "comp")
rel(root, ids["Elderly"],          ids["PillboxDevice"],    "uses",       "assoc")
rel(root, ids["Elderly"],          ids["QrToken"],          "has",        "comp")
rel(root, ids["QrToken"],          ids["ElderlyConnection"],"used in",    "assoc")
rel(root, ids["Elderly"],          ids["VoiceMessage"],     "receives",   "comp")

# Controllers → Services
rel(root, ids["AuthController"],     ids["AuthService"],        "uses", "dep")
rel(root, ids["ElderlyController"],  ids["ElderlyService"],     "uses", "dep")
rel(root, ids["EventsController"],   ids["EventsService"],      "uses", "dep")
rel(root, ids["EventsController"],   ids["NotificationService"],"uses", "dep")
rel(root, ids["EventsController"],   ids["SocketService"],      "uses", "dep")
rel(root, ids["SosController"],      ids["SosService"],         "uses", "dep")
rel(root, ids["PillboxController"],  ids["PillboxService"],     "uses", "dep")
rel(root, ids["EventsService"],      ids["MinioService"],       "uses", "dep")
rel(root, ids["SosController"],      ids["NotificationService"],"uses", "dep")
rel(root, ids["SosController"],      ids["SocketService"],      "uses", "dep")

# Python internal
rel(root, ids["Detector"],           ids["DetectionState"],     "has",   "comp")
rel(root, ids["Detector"],           ids["AlertSender"],        "alerts via", "dep")
rel(root, ids["Detector"],           ids["Config"],             "reads", "dep")
rel(root, ids["AlertSender"],        ids["Config"],             "reads", "dep")
rel(root, ids["WebRTCStreamer"],      ids["Config"],             "reads", "dep")

# Flutter internal
rel(root, ids["TodayStats"],         ids["EventModel"],         "built from", "dep")

# ── Serialise ────────────────────────────────────────────────────────────────
raw  = ET.tostring(mxfile, encoding="unicode")
pretty = minidom.parseString(raw).toprettyxml(indent="  ")

out = "/Users/sarah/Documents/PROJECT/SANAD/CLASS_DIAGRAM.drawio"
with open(out, "w", encoding="utf-8") as f:
    f.write(pretty)

print(f"✅  Wrote {out}")
print(f"   IDs allocated: {_id[0] - 2}")
