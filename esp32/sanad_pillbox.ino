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
 *        • Beep buzzer for 1 min, check IR every 50ms.
 *        • Repeat every 1 min for up to 30 min.
 *   4. IR sensor watches the slot:
 *        • Pill removed (IR breaks) → status = "taken" → POST to backend.
 *        • 30-min window expires and pill still there → status = "missed".
 *   5. Backend sends FCM push to caregiver on taken / missed.
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"

// ── ⚙️  CONFIGURATION ──────────────────────────────────────────────────────
const char* WIFI_SSID  = "Sarah";
const char* WIFI_PASS  = "sarahairrr";
const char* SERVER_URL = "http://10.227.83.165:3000/api/v1";  // ← your Mac IP
const char* ELDERLY_ID = "dfb409d3-7773-42b3-a70a-53d780d7dc92";

// ── Pin mapping ────────────────────────────────────────────────────────────
#define IR_SLOT1   4
#define IR_SLOT2   5
#define IR_SLOT3   18

#define LED_SLOT1  21
#define LED_SLOT2  22
#define LED_SLOT3  19

#define BUZZER_PIN 23

// ── Timing ─────────────────────────────────────────────────────────────────
#define REMINDER_INTERVAL_MS  (1  * 60 * 1000UL)   // retry every 1 min
#define REMINDER_WINDOW_MS    (30 * 60 * 1000UL)   // give up after 30 min
#define SCHEDULE_POLL_MS      (60 * 1000UL)         // poll schedule every 1 min

// ── Slot state ─────────────────────────────────────────────────────────────
struct SlotState {
  int    slot_number;
  String schedule_id;
  String slot_id;
  int    scheduled_hour;
  int    scheduled_min;
  String medication_name;
  String label;

  bool          active_window;
  unsigned long window_start;
  unsigned long last_reminder;
  bool          reported;
};

SlotState     slots[3];
int           slot_count = 0;
String        device_mac = "";
unsigned long last_poll  = 0;

// ─────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────

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

// LOW = IR beam broken = pill removed = taken
// If your sensor is reversed, change LOW → HIGH
bool irTriggered(int slot_number) {
  return digitalRead(irPin(slot_number)) == HIGH;  // HIGH = slot empty = pill taken
}


String getMac() {
  return WiFi.macAddress();
}

// ─────────────────────────────────────────────────────────────────────────
// WIFI
// ─────────────────────────────────────────────────────────────────────────

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
    beep(2, 100, 100);
  } else {
    Serial.println("\n[WiFi] FAILED — will retry next boot");
  }
}

// ─────────────────────────────────────────────────────────────────────────
// NTP TIME
// ─────────────────────────────────────────────────────────────────────────

void syncTime() {
  configTime(3 * 3600, 0, "pool.ntp.org", "time.nist.gov");  // UTC+3 Egypt
  Serial.print("[NTP] Syncing time");
  struct tm info;
  int tries = 0;
  while (!getLocalTime(&info) && tries < 20) {
    delay(500);
    Serial.print(".");
    tries++;
  }
  if (tries < 20) {
    char buf[20];
    strftime(buf, sizeof(buf), "%H:%M:%S", &info);
    Serial.printf("\n[NTP] Synced — %s\n", buf);
  } else {
    Serial.println("\n[NTP] Sync failed");
  }
}

void currentHM(int& h, int& m) {
  struct tm info;
  if (!getLocalTime(&info)) { h = 0; m = 0; return; }
  h = info.tm_hour;
  m = info.tm_min;
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

// ─────────────────────────────────────────────────────────────────────────
// BACKEND HTTP
// ─────────────────────────────────────────────────────────────────────────

bool registerDevice() {
  if (WiFi.status() != WL_CONNECTED) return false;

  HTTPClient http;
  http.begin(String(SERVER_URL) + "/pillbox/device/register");
  http.addHeader("Content-Type", "application/json");

  StaticJsonDocument<256> body;
  body["elderly_id"]       = ELDERLY_ID;
  body["device_mac"]       = device_mac;
  body["firmware_version"] = "1.0.0";

  String bodyStr;
  serializeJson(body, bodyStr);

  int  code = http.POST(bodyStr);
  bool ok   = (code == 200 || code == 201);
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
  if (deserializeJson(doc, payload)) {
    Serial.println("[Schedule] JSON parse error");
    return;
  }

  JsonArray schedule = doc["data"]["schedule"].as<JsonArray>();
  slot_count = 0;

  for (JsonObject entry : schedule) {
    if (slot_count >= 3) break;

    String timeStr = entry["scheduled_time"].as<String>();
    int h = timeStr.substring(0, 2).toInt();
    int m = timeStr.substring(3, 5).toInt();

    // Skip if already tracking this schedule (active alert running)
    bool already_active = false;
    for (int i = 0; i < slot_count; i++) {
      if (slots[i].schedule_id == entry["schedule_id"].as<String>()) {
        already_active = true;
        break;
      }
    }
    if (already_active) continue;

    SlotState& s      = slots[slot_count];
    s.slot_number     = entry["slot_number"].as<int>();
    s.schedule_id     = entry["schedule_id"].as<String>();
    s.slot_id         = entry["slot_id"].as<String>();
    s.scheduled_hour  = h;
    s.scheduled_min   = m;
    s.medication_name = entry["medication_name"].as<String>();
    s.label           = entry["label"] | "";
    s.active_window   = false;
    s.window_start    = 0;
    s.last_reminder   = 0;
    s.reported        = (
      strcmp(entry["dose_status"] | "pending", "taken")  == 0 ||
      strcmp(entry["dose_status"] | "pending", "missed") == 0
    );
    slot_count++;
  }

  Serial.printf("[Schedule] Loaded %d dose(s) for today\n", slot_count);
  for (int i = 0; i < slot_count; i++) {
    Serial.printf("  Slot %d → %02d:%02d (%s)\n",
      slots[i].slot_number,
      slots[i].scheduled_hour,
      slots[i].scheduled_min,
      slots[i].medication_name.c_str());
  }
}

void reportDose(SlotState& s, const char* status) {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  http.begin(String(SERVER_URL) + "/pillbox/device/report");
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

  s.reported = true;  // mark done — prevents double report
}

// ─────────────────────────────────────────────────────────────────────────
// REMINDER — non-blocking buzz, checks IR every 50ms
// ─────────────────────────────────────────────────────────────────────────

void activateReminder(SlotState& s) {
  digitalWrite(ledPin(s.slot_number), HIGH);
  Serial.printf("[Reminder] Slot %d — %s @ %02d:%02d\n",
                s.slot_number,
                s.medication_name.c_str(),
                s.scheduled_hour,
                s.scheduled_min);

  // Buzz for 1 minute — check IR every 50ms
  unsigned long buzzStart = millis();
  while (millis() - buzzStart < 60000UL) {

    // ✅ FIX: Pill taken? Stop immediately — no double report
    if (irTriggered(s.slot_number)) {
      digitalWrite(BUZZER_PIN, LOW);
      digitalWrite(ledPin(s.slot_number), LOW);
      Serial.printf("[TAKEN] Slot %d — pill taken during alert!\n", s.slot_number);
      reportDose(s, "taken");  // sets s.reported = true
      return;
    }

    // Beep pattern: 500ms ON, 500ms OFF
    unsigned long elapsed = millis() - buzzStart;
    digitalWrite(BUZZER_PIN, (elapsed % 1000UL) < 500UL ? HIGH : LOW);
    delay(50);
  }

  digitalWrite(BUZZER_PIN, LOW);
  // LED stays on — main loop handles retry
}

void deactivateLed(SlotState& s) {
  digitalWrite(ledPin(s.slot_number), LOW);
}

// ─────────────────────────────────────────────────────────────────────────
// SETUP
// ─────────────────────────────────────────────────────────────────────────

void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);  // MUST BE FIRST

  Serial.begin(115200);
  Serial.println("\n╔══════════════════════════════╗");
  Serial.println("║  SANAD Smart Pillbox v2.0    ║");
  Serial.println("╚══════════════════════════════╝");

  pinMode(LED_SLOT1,  OUTPUT);
  pinMode(LED_SLOT2,  OUTPUT);
  pinMode(LED_SLOT3,  OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(IR_SLOT1,   INPUT_PULLUP);
  pinMode(IR_SLOT2,   INPUT_PULLUP);
  pinMode(IR_SLOT3,   INPUT_PULLUP);

  digitalWrite(LED_SLOT1,  LOW);
  digitalWrite(LED_SLOT2,  LOW);
  digitalWrite(LED_SLOT3,  LOW);
  digitalWrite(BUZZER_PIN, LOW);

  delay(1000);
  WiFi.mode(WIFI_STA);
  delay(300);
  WiFi.setTxPower(WIFI_POWER_2dBm);
  delay(300);

  device_mac = getMac();
  Serial.println("[Device] MAC: " + device_mac);

  connectWifi();
  syncTime();

  if (WiFi.status() == WL_CONNECTED) {
    registerDevice();
    fetchSchedule();
    last_poll = millis();
  }

  beep(1, 500);
}

// ─────────────────────────────────────────────────────────────────────────
// MAIN LOOP
// ─────────────────────────────────────────────────────────────────────────

void loop() {
  unsigned long now = millis();

  // ── WiFi watchdog ──────────────────────────────────────────────
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] Reconnecting...");
    WiFi.reconnect();
    delay(3000);
    return;
  }

  // ── Poll schedule every minute ─────────────────────────────────
  if (now - last_poll >= SCHEDULE_POLL_MS) {
    fetchSchedule();
    last_poll = now;
  }

  // ── IR debug (uncomment to test sensor direction) ──────────────
  // Serial.printf("IR1=%d IR2=%d IR3=%d\n",
  //   digitalRead(IR_SLOT1), digitalRead(IR_SLOT2), digitalRead(IR_SLOT3));

  int cur_h, cur_m;
  currentHM(cur_h, cur_m);
  int cur_total = cur_h * 60 + cur_m;

  for (int i = 0; i < slot_count; i++) {
    SlotState& s = slots[i];
    if (s.reported) continue;

    int sch_total = s.scheduled_hour * 60 + s.scheduled_min;

    // ── Scheduled time reached — start alert window ────────────
    if (!s.active_window && cur_total >= sch_total) {
      s.active_window = true;
      s.window_start  = now;
      s.last_reminder = now;
      activateReminder(s);
      if (s.reported) continue;  // ✅ FIX: pill taken inside reminder, skip loop
    }

    if (!s.active_window) continue;

    // ── Check IR between reminders ─────────────────────────────
    if (irTriggered(s.slot_number)) {
      deactivateLed(s);
      Serial.printf("[IR] Slot %d — TAKEN\n", s.slot_number);
      reportDose(s, "taken");
      continue;
    }

    // ── Retry reminder every 1 minute ─────────────────────────
    if (now - s.last_reminder >= REMINDER_INTERVAL_MS) {
      s.last_reminder = now;
      activateReminder(s);
      if (s.reported) continue;  // ✅ FIX: pill taken inside reminder
    }

    // ── 30-min window expired → missed ────────────────────────
    if (now - s.window_start >= REMINDER_WINDOW_MS) {
      deactivateLed(s);
      Serial.printf("[Window] Slot %d — MISSED\n", s.slot_number);
      reportDose(s, "missed");
    }
  }

  delay(500);
}