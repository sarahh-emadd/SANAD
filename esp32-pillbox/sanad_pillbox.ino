/**
 * SANAD Smart Pillbox — ESP32S Firmware
 * ======================================
 * Hardware:
 *   - ESP32-S Dev Module
 *   - 3 IR sensors  (slots 1, 2, 3)
 *   - 3 LEDs        (slots 1, 2, 3)
 *   - 1 Buzzer
 *   - LiPo battery
 *
 * Behaviour:
 *   1. On boot → connect WiFi, sync NTP, register with SANAD backend.
 *   2. Every 60 s → poll /pillbox/device/schedule for today's doses.
 *   3. When a scheduled time arrives:
 *        • Turn on the slot LED.
 *        • Beep buzzer for 2 s.
 *        • Repeat every 5 min for up to 30 min (7 reminders total).
 *   4. IR sensor watches the open slot lid:
 *        • Pill removed (IR breaks) → status = "taken" → POST to backend.
 *        • 30-min window expires and pill still there → status = "missed".
 *   5. Backend sends FCM push to caregiver on taken / missed.
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>

// ── ⚙️  CONFIGURATION — edit these before flashing ───────────────────────────
const char* WIFI_SSID      = "YOUR_WIFI_SSID";
const char* WIFI_PASS      = "YOUR_WIFI_PASSWORD";
const char* SERVER_URL     = "http://192.168.1.254:3000/api/v1";  // your server IP
const char* ELDERLY_ID     = "PASTE_ELDERLY_UUID_HERE";           // from DB
// MAC is read automatically at runtime — no need to set it

// ── Pin mapping ───────────────────────────────────────────────────────────────
#define IR_SLOT1   34   // IR sensor slot 1 (INPUT only on ESP32)
#define IR_SLOT2   35   // IR sensor slot 2
#define IR_SLOT3   32   // IR sensor slot 3

#define LED_SLOT1  25   // LED slot 1
#define LED_SLOT2  26   // LED slot 2
#define LED_SLOT3  27   // LED slot 3

#define BUZZER_PIN 14   // Active or passive buzzer

// ── Reminder config ───────────────────────────────────────────────────────────
#define REMINDER_INTERVAL_MS  (5  * 60 * 1000UL)   // 5 minutes
#define REMINDER_WINDOW_MS    (30 * 60 * 1000UL)   // 30-minute window
#define SCHEDULE_POLL_MS      (60 * 1000UL)         // poll server every 60 s

// ── Slot state ────────────────────────────────────────────────────────────────
struct SlotState {
  int    slot_number;
  String schedule_id;
  String slot_id;
  int    scheduled_hour;
  int    scheduled_min;
  String medication_name;
  String label;

  bool   active_window;        // true = we are in the 30-min reminder window
  unsigned long window_start;  // millis() when window opened
  unsigned long last_reminder; // millis() of last beep/LED
  bool   reported;             // true = already sent taken/missed to server
};

SlotState slots[3];
int       slot_count = 0;
String    device_mac = "";

unsigned long last_poll = 0;

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

void beep(int times, int on_ms = 300, int off_ms = 200) {
  for (int i = 0; i < times; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(on_ms);
    digitalWrite(BUZZER_PIN, LOW);
    if (i < times - 1) delay(off_ms);
  }
}

int ledPin(int slot_number) {
  if (slot_number == 1) return LED_SLOT1;
  if (slot_number == 2) return LED_SLOT2;
  return LED_SLOT3;
}

int irPin(int slot_number) {
  if (slot_number == 1) return IR_SLOT1;
  if (slot_number == 2) return IR_SLOT2;
  return IR_SLOT3;
}

bool irTriggered(int slot_number) {
  // Most IR break-beam modules output LOW when beam is broken (pill removed)
  return digitalRead(irPin(slot_number)) == LOW;
}

String getMac() {
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  char buf[20];
  snprintf(buf, sizeof(buf), "%02X:%02X:%02X:%02X:%02X:%02X",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  return String(buf);
}

// ─────────────────────────────────────────────────────────────────────────────
// WIFI
// ─────────────────────────────────────────────────────────────────────────────

void connectWifi() {
  Serial.print("[WiFi] Connecting to ");
  Serial.print(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WiFi] Connected — IP: " + WiFi.localIP().toString());
    beep(2, 100, 100);  // 2 short beeps = connected
  } else {
    Serial.println("\n[WiFi] FAILED — will retry next boot");
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NTP TIME
// ─────────────────────────────────────────────────────────────────────────────

void syncTime() {
  configTime(3 * 3600, 0, "pool.ntp.org", "time.nist.gov");  // UTC+3 (Cairo)
  Serial.print("[NTP] Syncing time");
  struct tm info;
  int tries = 0;
  while (!getLocalTime(&info) && tries < 20) {
    delay(500);
    Serial.print(".");
    tries++;
  }
  Serial.println(tries < 20 ? "\n[NTP] Time synced" : "\n[NTP] Sync failed");
}

void currentHM(int& h, int& m) {
  struct tm info;
  if (!getLocalTime(&info)) { h = 0; m = 0; return; }
  h = info.tm_hour;
  m = info.tm_min;
}

// Full ISO timestamp for scheduled_at field
String isoNow() {
  struct tm info;
  if (!getLocalTime(&info)) return "1970-01-01T00:00:00Z";
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S", &info);
  return String(buf);
}

String isoFromHM(int h, int m) {
  struct tm info;
  if (!getLocalTime(&info)) return "1970-01-01T00:00:00Z";
  info.tm_hour = h;
  info.tm_min  = m;
  info.tm_sec  = 0;
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S", &info);
  return String(buf);
}

// ─────────────────────────────────────────────────────────────────────────────
// BACKEND HTTP
// ─────────────────────────────────────────────────────────────────────────────

bool registerDevice() {
  if (WiFi.status() != WL_CONNECTED) return false;

  HTTPClient http;
  String url = String(SERVER_URL) + "/pillbox/device/register";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  StaticJsonDocument<256> body;
  body["elderly_id"]       = ELDERLY_ID;
  body["device_mac"]       = device_mac;
  body["firmware_version"] = "1.0.0";

  String bodyStr;
  serializeJson(body, bodyStr);

  int code = http.POST(bodyStr);
  bool ok  = (code == 200 || code == 201);
  Serial.printf("[Register] HTTP %d — %s\n", code, ok ? "OK" : "FAILED");
  http.end();
  return ok;
}

void fetchSchedule() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(SERVER_URL) + "/pillbox/device/schedule"
               + "?elderly_id=" + ELDERLY_ID
               + "&device_mac=" + device_mac;
  http.begin(url);
  int code = http.GET();

  if (code != 200) {
    Serial.printf("[Schedule] HTTP %d\n", code);
    http.end();
    return;
  }

  String payload = http.getString();
  http.end();

  StaticJsonDocument<2048> doc;
  DeserializationError err = deserializeJson(doc, payload);
  if (err) {
    Serial.println("[Schedule] JSON parse error");
    return;
  }

  JsonArray schedule = doc["data"]["schedule"].as<JsonArray>();
  slot_count = 0;

  int cur_h, cur_m;
  currentHM(cur_h, cur_m);

  for (JsonObject entry : schedule) {
    if (slot_count >= 3) break;

    // Parse "HH:MM"
    String timeStr = entry["scheduled_time"].as<String>();
    int h = timeStr.substring(0, 2).toInt();
    int m = timeStr.substring(3, 5).toInt();

    // Check if this slot already has an active window in our state
    // (don't reset if the window is already open)
    bool already_active = false;
    for (int i = 0; i < slot_count; i++) {
      if (slots[i].schedule_id == entry["schedule_id"].as<String>()) {
        already_active = true;
        break;
      }
    }

    if (!already_active) {
      SlotState& s        = slots[slot_count];
      s.slot_number       = entry["slot_number"].as<int>();
      s.schedule_id       = entry["schedule_id"].as<String>();
      s.slot_id           = entry["slot_id"].as<String>();
      s.scheduled_hour    = h;
      s.scheduled_min     = m;
      s.medication_name   = entry["medication_name"].as<String>();
      s.label             = entry["label"] | "";
      s.active_window     = false;
      s.window_start      = 0;
      s.last_reminder     = 0;
      s.reported          = (
        strcmp(entry["dose_status"] | "pending", "taken")  == 0 ||
        strcmp(entry["dose_status"] | "pending", "missed") == 0
      );
      slot_count++;
    }
  }

  Serial.printf("[Schedule] Loaded %d dose(s) for today\n", slot_count);
}

void reportDose(SlotState& s, const char* status) {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(SERVER_URL) + "/pillbox/device/report";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  StaticJsonDocument<512> body;
  body["device_mac"]   = device_mac;
  body["elderly_id"]   = ELDERLY_ID;
  body["schedule_id"]  = s.schedule_id;
  body["slot_id"]      = s.slot_id;
  body["slot_number"]  = s.slot_number;
  body["scheduled_at"] = isoFromHM(s.scheduled_hour, s.scheduled_min);
  body["status"]       = status;

  String bodyStr;
  serializeJson(body, bodyStr);

  int code = http.POST(bodyStr);
  Serial.printf("[Report] Slot %d → %s | HTTP %d\n",
                s.slot_number, status, code);
  http.end();

  s.reported = true;
}

// ─────────────────────────────────────────────────────────────────────────────
// REMINDER LOGIC
// ─────────────────────────────────────────────────────────────────────────────

void activateReminder(SlotState& s) {
  int pin = ledPin(s.slot_number);
  digitalWrite(pin, HIGH);

  // 3 short beeps
  beep(3, 200, 150);

  Serial.printf("[Reminder] Slot %d — %s @ %02d:%02d\n",
                s.slot_number,
                s.medication_name.c_str(),
                s.scheduled_hour,
                s.scheduled_min);
}

void deactivateLed(SlotState& s) {
  digitalWrite(ledPin(s.slot_number), LOW);
}

// ─────────────────────────────────────────────────────────────────────────────
// SETUP
// ─────────────────────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  Serial.println("\n╔══════════════════════════════╗");
  Serial.println("║  SANAD Smart Pillbox v1.0    ║");
  Serial.println("╚══════════════════════════════╝");

  // Pin setup
  pinMode(LED_SLOT1, OUTPUT);
  pinMode(LED_SLOT2, OUTPUT);
  pinMode(LED_SLOT3, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(IR_SLOT1, INPUT_PULLUP);
  pinMode(IR_SLOT2, INPUT_PULLUP);
  pinMode(IR_SLOT3, INPUT_PULLUP);

  // All LEDs off
  digitalWrite(LED_SLOT1, LOW);
  digitalWrite(LED_SLOT2, LOW);
  digitalWrite(LED_SLOT3, LOW);
  digitalWrite(BUZZER_PIN, LOW);

  // Get MAC
  device_mac = getMac();
  Serial.println("[Device] MAC: " + device_mac);

  // Connect
  connectWifi();
  syncTime();

  // Register with backend
  if (WiFi.status() == WL_CONNECTED) {
    registerDevice();
    fetchSchedule();
    last_poll = millis();
  }

  // Startup beep: 1 long = ready
  beep(1, 500);
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN LOOP
// ─────────────────────────────────────────────────────────────────────────────

void loop() {
  unsigned long now = millis();

  // Reconnect WiFi if dropped
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] Reconnecting...");
    WiFi.reconnect();
    delay(3000);
    return;
  }

  // Poll schedule every 60 s
  if (now - last_poll >= SCHEDULE_POLL_MS) {
    fetchSchedule();
    last_poll = now;
  }

  // Current time
  int cur_h, cur_m;
  currentHM(cur_h, cur_m);
  int cur_total = cur_h * 60 + cur_m;

  // Process each slot
  for (int i = 0; i < slot_count; i++) {
    SlotState& s = slots[i];
    if (s.reported) continue;

    int sch_total = s.scheduled_hour * 60 + s.scheduled_min;

    // ── Open window when scheduled time arrives ───────────────────────────
    if (!s.active_window && cur_total >= sch_total) {
      s.active_window  = true;
      s.window_start   = now;
      s.last_reminder  = now;
      activateReminder(s);
    }

    if (!s.active_window) continue;

    // ── IR check: pill taken? ─────────────────────────────────────────────
    if (irTriggered(s.slot_number)) {
      deactivateLed(s);
      Serial.printf("[IR] Slot %d — TAKEN\n", s.slot_number);
      reportDose(s, "taken");
      continue;
    }

    // ── Repeat reminder every 5 min ───────────────────────────────────────
    if (now - s.last_reminder >= REMINDER_INTERVAL_MS) {
      s.last_reminder = now;
      activateReminder(s);
    }

    // ── Window expired: mark missed ───────────────────────────────────────
    if (now - s.window_start >= REMINDER_WINDOW_MS) {
      deactivateLed(s);
      Serial.printf("[Window] Slot %d — MISSED\n", s.slot_number);
      reportDose(s, "missed");
    }
  }

  delay(500);  // check every 500 ms
}
