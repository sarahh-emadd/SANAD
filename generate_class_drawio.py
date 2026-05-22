#!/usr/bin/env python3
"""
SANAD Class Diagram — clean overview version.
One box per major class, key attributes only, grouped by layer.
Run: python3 generate_class_drawio.py
"""

import xml.etree.ElementTree as ET
from xml.dom import minidom

_id = [2]
def nid(): i = _id[0]; _id[0] += 1; return str(i)

ROW_H = 18
HEAD_H = 28
W = 200   # class box width

# ── colours (fill, stroke, font) ─────────────────────────────────────
LAYERS = {
    "db":      ("#dae8fc", "#006EAF", "#000000"),   # blue
    "pillbox": ("#d5e8d4", "#82b366", "#000000"),   # green
    "backend": ("#fff2cc", "#d6b656", "#000000"),   # yellow
    "python":  ("#f8cecc", "#b85450", "#000000"),   # red
    "flutter": ("#e1d5e7", "#9673a6", "#000000"),   # purple
    "esp32":   ("#f0f0f0", "#666666", "#000000"),   # grey
    "group":   ("#f5f5f5", "#999999", "#333333"),   # container
}

def make_class(root, name, items, x, y, layer, w=W):
    """items = list of strings (fields or methods, keep short)"""
    fill, stroke, font = LAYERS[layer]
    h = HEAD_H + len(items) * ROW_H + 4
    cid = nid()
    c = ET.SubElement(root, "mxCell", {
        "id": cid, "value": name,
        "style": (f"swimlane;startSize={HEAD_H};fontStyle=1;fontSize=11;"
                  f"align=center;fillColor={fill};strokeColor={stroke};"
                  f"fontColor={font};"),
        "vertex": "1", "parent": "1"
    })
    ET.SubElement(c, "mxGeometry", {
        "x": str(x), "y": str(y),
        "width": str(w), "height": str(h), "as": "geometry"
    })
    fs = ("text;strokeColor=none;fillColor=none;align=left;"
          "verticalAlign=middle;spacingLeft=6;overflow=hidden;"
          "rotatable=0;fontSize=10;")
    cy = HEAD_H
    for item in items:
        fc = ET.SubElement(root, "mxCell", {
            "id": nid(), "value": item, "style": fs,
            "vertex": "1", "parent": cid
        })
        ET.SubElement(fc, "mxGeometry", {
            "y": str(cy), "width": str(w), "height": str(ROW_H),
            "as": "geometry"
        })
        cy += ROW_H
    return cid, h

def make_group(root, label, x, y, w, h, layer="group"):
    fill, stroke, font = LAYERS[layer]
    gid = nid()
    g = ET.SubElement(root, "mxCell", {
        "id": gid, "value": label,
        "style": (f"swimlane;startSize=24;fontStyle=1;fontSize=12;"
                  f"align=left;fillColor={fill};strokeColor={stroke};"
                  f"fontColor={font};dashed=1;dashPattern=6 3;rounded=1;"),
        "vertex": "1", "parent": "1"
    })
    ET.SubElement(g, "mxGeometry", {
        "x": str(x), "y": str(y),
        "width": str(w), "height": str(h), "as": "geometry"
    })
    return gid

def arrow(root, src, tgt, label="", style="dep"):
    s = {
        "dep":   "endArrow=open;endFill=0;dashed=1;strokeColor=#555;fontSize=9;",
        "assoc": "endArrow=open;endFill=0;strokeColor=#555;fontSize=9;",
        "comp":  "endArrow=ERmany;endFill=1;startArrow=ERmandOne;startFill=0;strokeColor=#555;fontSize=9;",
    }
    ec = ET.SubElement(root, "mxCell", {
        "id": nid(), "value": label,
        "style": s.get(style, s["dep"]),
        "edge": "1", "source": src, "target": tgt, "parent": "1"
    })
    ET.SubElement(ec, "mxGeometry", {"relative": "1", "as": "geometry"})

def label_box(root, text, x, y, w=160, h=24, bold=False):
    fs = f"fontStyle={'1' if bold else '0'};fontSize=11;fillColor=none;strokeColor=none;"
    lc = ET.SubElement(root, "mxCell", {
        "id": nid(), "value": text, "style": fs,
        "vertex": "1", "parent": "1"
    })
    ET.SubElement(lc, "mxGeometry", {
        "x": str(x), "y": str(y),
        "width": str(w), "height": str(h), "as": "geometry"
    })

# ── Build graph ──────────────────────────────────────────────────────
mxfile  = ET.Element("mxfile", {"host": "app.diagrams.net"})
diagram = ET.SubElement(mxfile, "diagram", {"name": "SANAD Class Diagram"})
model   = ET.SubElement(diagram, "mxGraphModel", {
    "dx": "1422", "dy": "762", "grid": "0", "gridSize": "10",
    "guides": "1", "tooltips": "1", "connect": "1", "arrows": "1",
    "fold": "1", "page": "1", "pageScale": "1",
    "pageWidth": "1654", "pageHeight": "1169",
    "math": "0", "shadow": "1"
})
root = ET.SubElement(model, "root")
ET.SubElement(root, "mxCell", {"id": "0"})
ET.SubElement(root, "mxCell", {"id": "1", "parent": "0"})

ids = {}
def C(name, items, x, y, layer, w=W):
    cid, h = make_class(root, name, items, x, y, layer, w)
    ids[name] = cid
    return h

GAP = 16   # gap between boxes

# ════════════════════════════════════════════════════════════════════
#  ROW 1  —  DATABASE  (top, spans full width)
# ════════════════════════════════════════════════════════════════════
DB_Y = 60
make_group(root, "🗄  Database  (PostgreSQL)", 20, 40, 1614, 220, "group")

x = 40
h = C("Caregiver", [
    "id, firebase_uid, email",
    "first_name, last_name",
    "fcm_token, status",
], x, DB_Y, "db"); x += W + GAP

h = C("Elderly", [
    "id, caregiver_id  [FK]",
    "first_name, last_name",
    "sleep_time, wake_time",
    "is_connected, status",
], x, DB_Y, "db"); x += W + GAP

h = C("Event", [
    "id, elderly_id  [FK]",
    "event_type:",
    "  fall | inactivity | sleeping",
    "  night_restlessness",
    "confidence, snapshot_url",
    "verified, alert_sent",
], x, DB_Y, "db"); x += W + GAP

h = C("SosRequest", [
    "id, elderly_id  [FK]",
    "caregiver_id  [FK]",
    "status, source",
    "  manual | auto_fall",
], x, DB_Y, "db"); x += W + GAP

h = C("PillSlot", [
    "id, elderly_id  [FK]",
    "slot_number  (1–3)",
    "medication_name",
], x, DB_Y, "pillbox"); x += W + GAP

h = C("PillSchedule", [
    "id, slot_id  [FK]",
    "scheduled_time",
    "days_of_week[ ]",
], x, DB_Y, "pillbox"); x += W + GAP

h = C("PillLog", [
    "id, schedule_id  [FK]",
    "status:",
    "  taken | missed | pending",
    "taken_at, notified",
], x, DB_Y, "pillbox"); x += W + GAP

h = C("Camera", [
    "id, elderly_id  [FK]",
    "camera_device_id",
    "status",
], x, DB_Y, "db"); x += W + GAP

h = C("ElderLocation", [
    "elderly_id  [FK]",
    "latitude, longitude",
    "battery_level, last_seen",
], x, DB_Y, "db")

# ════════════════════════════════════════════════════════════════════
#  ROW 2  —  BACKEND  +  PYTHON AI  +  ESP32
# ════════════════════════════════════════════════════════════════════
ROW2_Y = 290

# ── Backend group ────────────────────────────────────────
make_group(root, "⚙️  Node.js Backend", 20, ROW2_Y - 20, 860, 420, "group")

x = 40
h = C("AuthService /\nAuthController", [
    "+ syncUser(uid, email)",
    "+ getCaregiverByUid(uid)",
    "+ updateFcmToken(id, token)",
    "+ updateProfile(id, data)",
], x, ROW2_Y, "backend", W); x += W + GAP

h = C("ElderlyService /\nElderlyController", [
    "+ create(caregiverId, data)",
    "+ getAll(caregiverId)",
    "+ update(elderlyId, data)",
    "+ delete(elderlyId)",
    "+ disconnectDevice(elderlyId)",
], x, ROW2_Y, "backend", W); x += W + GAP

h = C("EventsService /\nEventsController", [
    "+ createEvent(elderlyId, data)",
    "+ getEventsByElderly(id)",
    "+ verifyEvent(id, cgId, fp)",
    "+ getTodayStats(elderlyId)",
    "  → {fall, inactivity, sleeping,",
    "     night_restlessness, total}",
], x, ROW2_Y, "backend", W); x += W + GAP

h = C("SosService /\nSosController", [
    "+ createSos(elderlyId, source)",
    "+ acknowledgeSos(sosId)",
    "+ getSosHistory(caregiverId)",
], x, ROW2_Y, "backend", W); x += W + GAP

h = C("PillboxService /\nPillboxController", [
    "+ getSlots(elderlyId)",
    "+ addSchedule(slotId, data)",
    "+ getTodaySchedule(elderlyId)",
    "+ upsertLog(schedId, status)",
    "+ registerDevice(mac, id)",
    "+ reportDose(req, res)",
], x, ROW2_Y, "pillbox", W); x += W + GAP

# second row inside backend group (support services)
x2 = 40
h2 = C("NotificationService", [
    "+ sendEventAlert(id, type, conf)",
    "+ sendSosAlert(id, sosId, src)",
    "+ sendGeofenceAlert(id, dist)",
    "+ sendRawNotification(token, msg)",
], x2, ROW2_Y + 190, "backend", W); x2 += W + GAP

h2 = C("MinioService", [
    "+ uploadSnapshot(id, buf, type)",
    "+ getSignedUrl(objectName)",
    "+ deleteFile(objectName)",
], x2, ROW2_Y + 190, "backend", W); x2 += W + GAP

h2 = C("SocketService", [
    "+ initializeSocket(server)",
    "+ emitAlert(io, cgId, data)",
    "+ emitSosAlert(io, cgId, data)",
], x2, ROW2_Y + 190, "backend", W)

# ── Python AI group ──────────────────────────────────────
make_group(root, "🐍  Python AI Module", 900, ROW2_Y - 20, 440, 420, "group")

px = 916
h = C("Detector", [
    "─ process_frame(frame)",
    "─ _check_fall(lm, frame)",
    "─ _check_inactivity(lm, frame)",
    "─ _check_sleeping(lm, frame)",
    "─ _check_night_restlessness()",
    "─ analyze_fall(lm, history)",
    "─ detect_inactivity(frm, prv, t)",
], px, ROW2_Y, "python", W)

h = C("DetectionState", [
    "fall_start_time, last_fall_time",
    "posture_history  deque(60)",
    "prev_frame",
    "last_inactivity_warning_time",
    "last_inactivity_critical_time",
    "night_restlessness_start",
    "sleep_start_time",
], px + W + GAP, ROW2_Y, "python", W)

h = C("AlertSender", [
    "server_url, elderly_id",
    "─ send_event(type, conf, frame)",
    "─ fetch_elderly_id(cam_id)",
], px, ROW2_Y + 200, "python", W)

h = C("WebRTCStreamer", [
    "pc: RTCPeerConnection",
    "─ connect(elderly_id, cg_id)",
    "─ send_frame(frame)",
    "─ disconnect()",
], px + W + GAP, ROW2_Y + 200, "python", W)

# ── ESP32 group ──────────────────────────────────────────
make_group(root, "📟  ESP32 Pillbox", 1360, ROW2_Y - 20, 254, 420, "group")

ex = 1376
h = C("ESP32Firmware", [
    "WIFI_SSID, WIFI_PASS",
    "SERVER_URL, ELDERLY_ID",
    "IR_SLOT1/2/3  (pins 34/35/32)",
    "LED_SLOT1/2/3 (pins 25/26/27)",
    "BUZZER_PIN  (pin 14)",
    "─ connectWifi()",
    "─ syncTime()  (NTP)",
    "─ fetchSchedule()",
    "─ reportDose(slot, status)",
    "─ activateReminder(slot)",
], ex, ROW2_Y, "esp32", 220)

# ════════════════════════════════════════════════════════════════════
#  ROW 3  —  FLUTTER
# ════════════════════════════════════════════════════════════════════
ROW3_Y = 740
make_group(root, "📱  Flutter Mobile App", 20, ROW3_Y - 20, 1594, 380, "group")

x = 40
h = C("ElderlyModel", [
    "id, caregiverId",
    "firstName, lastName",
    "medicalConditions",
    "typicalSleepTime / WakeTime",
    "isConnected",
    "get fullName()",
], x, ROW3_Y, "flutter"); x += W + GAP

h = C("EventModel", [
    "id, elderlyId, eventType",
    "confidence, snapshotUrl",
    "verified, isFalsePositive",
    "get title()  ← night_restlessness",
    "get confidencePercent()",
    "get timeAgo()",
], x, ROW3_Y, "flutter"); x += W + GAP

h = C("TodayStats", [
    "falls : int",
    "inactivity : int",
    "sleeping : int",
    "nightRestlessness : int  ← new",
    "total : int",
    "get activityLevel()",
], x, ROW3_Y, "flutter"); x += W + GAP

h = C("QrModel", [
    "token, manualCode  (6 digits)",
    "expiresAt, isActive",
    "get isValid()",
    "get remainingMinutes()",
], x, ROW3_Y, "flutter"); x += W + GAP

h = C("WebRTCService", [
    "caregiverId, elderlyId",
    "onConnected, onAlert",
    "onCameraOffline",
    "─ connect() / disconnect()",
    "─ createOffer()",
    "─ handleAnswer(answer)",
], x, ROW3_Y, "flutter"); x += W + GAP

h = C("LocationService", [
    "─ reportLocation(elderlyId)",
    "─ startPeriodicReporting()",
    "─ stopReporting()",
], x, ROW3_Y, "flutter"); x += W + GAP

h = C("SosService", [
    "─ triggerSos(elderlyId)",
    "─ acknowledgeSos(sosId)",
    "─ getSosHistory()",
], x, ROW3_Y, "flutter"); x += W + GAP

h = C("VoiceReminderService", [
    "─ getReminders(elderlyId)",
    "─ createReminder(id, title)",
    "─ sendReminder(reminderId)",
    "─ deleteReminder(id)",
], x, ROW3_Y, "flutter")

# ════════════════════════════════════════════════════════════════════
#  RELATIONSHIPS  (keep only the most important)
# ════════════════════════════════════════════════════════════════════

# DB structure
arrow(root, ids["Caregiver"],    ids["Elderly"],          "owns",      "assoc")
arrow(root, ids["Elderly"],      ids["Event"],            "generates", "comp")
arrow(root, ids["Elderly"],      ids["SosRequest"],       "triggers",  "comp")
arrow(root, ids["Elderly"],      ids["PillSlot"],         "has 3",     "comp")
arrow(root, ids["PillSlot"],     ids["PillSchedule"],     "schedules", "comp")
arrow(root, ids["PillSchedule"], ids["PillLog"],          "logs",      "comp")
arrow(root, ids["Elderly"],      ids["Camera"],           "uses",      "assoc")

# Backend → DB
arrow(root, ids["EventsService /\nEventsController"],
            ids["Event"],                                 "creates",   "dep")
arrow(root, ids["SosService /\nSosController"],
            ids["SosRequest"],                            "creates",   "dep")
arrow(root, ids["PillboxService /\nPillboxController"],
            ids["PillLog"],                               "writes",    "dep")

# Backend support
arrow(root, ids["EventsService /\nEventsController"],
            ids["NotificationService"],                   "uses",      "dep")
arrow(root, ids["EventsService /\nEventsController"],
            ids["SocketService"],                         "uses",      "dep")
arrow(root, ids["SosService /\nSosController"],
            ids["NotificationService"],                   "uses",      "dep")

# Python → Backend
arrow(root, ids["AlertSender"],
            ids["EventsService /\nEventsController"],     "POST /events", "dep")

# Python internal
arrow(root, ids["Detector"],     ids["DetectionState"],  "has",       "comp")
arrow(root, ids["Detector"],     ids["AlertSender"],     "alerts via","dep")
arrow(root, ids["WebRTCStreamer"],ids["SocketService"],   "streams to","dep")

# ESP32 → Backend
arrow(root, ids["ESP32Firmware"],
            ids["PillboxService /\nPillboxController"],   "reportDose","dep")

# Flutter → Backend
arrow(root, ids["WebRTCService"],
            ids["SocketService"],                         "WebRTC sig.","dep")
arrow(root, ids["SosService"],
            ids["SosService /\nSosController"],           "REST",      "dep")
arrow(root, ids["TodayStats"],   ids["EventModel"],      "built from","dep")

# ── Serialise ────────────────────────────────────────────────────────
raw    = ET.tostring(mxfile, encoding="unicode")
pretty = minidom.parseString(raw).toprettyxml(indent="  ")

out = "/Users/sarah/Documents/PROJECT/SANAD/CLASS_DIAGRAM.drawio"
with open(out, "w", encoding="utf-8") as f:
    f.write(pretty)

print(f"✅  {out}")
print(f"   IDs used: {_id[0] - 2}")
