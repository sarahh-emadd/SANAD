import 'package:flutter/foundation.dart';

/// ── HOW TO SET YOUR SERVER URL ─────────────────────────────────────────────
///
/// Option A — Recommended for production or real-device testing:
///   Deploy your Node.js server and pass the URL at build time:
///
///   flutter run  --dart-define=API_URL=https://your-server.com
///   flutter build apk --dart-define=API_URL=https://your-server.com
///   flutter build ios --dart-define=API_URL=https://your-server.com
///
/// Option B — Local development on a real iOS/Android device (same Wi-Fi):
///   1. Find your Mac/PC IP:  run `ipconfig getifaddr en0` (Mac) or
///                                `ipconfig` (Windows, look for IPv4)
///   2. Update the return value at the bottom of _host with that IP.
///   3. Rebuild the app.
///
///   Note: this IP changes if you switch networks. Prefer Option A.
///
/// ──────────────────────────────────────────────────────────────────────────

// ── Production server (Railway) ───────────────────────────────────────────
const String _kProductionUrl = 'https://sanad-production-ae45.up.railway.app';

class ApiConfig {
  static String get _host {
    // ── Production build: flutter run --dart-define=API_URL=https://...  ──
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // ── Local development default → Docker (teammates just run docker-compose up) ──
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000';
    if (defaultTargetPlatform == TargetPlatform.macOS)   return 'http://localhost:3000';

    // ── iOS Simulator & real device on same Mac ───────────────────────
    return 'http://localhost:3000';
  }

  static const String _version = '/api/v1';
  static String get baseUrl => _host + _version;

  // ── Socket URL (no /api/v1 prefix) ────────────────────────────────
  static String get socketUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl.replaceAll('/api/v1', '');

    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  // ── Auth ───────────────────────────────────────────────────────────
  static String get syncUser => '$baseUrl/auth/sync';
  static String get checkEmail => '$baseUrl/auth/check-email';
  static String get getMe => '$baseUrl/auth/me';
  static String get updateProfile => '$baseUrl/auth/profile';
  static String get updateFcmToken => '$baseUrl/auth/fcm-token';
  static String get deleteAccount => '$baseUrl/auth/account';

  // ── Elderly ────────────────────────────────────────────────────────
  static String get createElderly => '$baseUrl/elderly';
  static String get getAllElderly => '$baseUrl/elderly';
  static String get elderlyStats => '$baseUrl/elderly/stats';
  static String elderlyById(String id) => '$baseUrl/elderly/$id';
  static String elderlyQR(String id) => '$baseUrl/elderly/$id/qr';
  static String regenerateQR(String id) => '$baseUrl/elderly/$id/regenerate-qr';
  static String updateElderly(String id) => '$baseUrl/elderly/$id';
  static String deleteElderly(String id) => '$baseUrl/elderly/$id';
  static String disconnectDevice(String id) =>
      '$baseUrl/elderly/$id/disconnect';

  // ── QR ─────────────────────────────────────────────────────────────
  static String get connectQR => '$baseUrl/qr/connect';
  static String get connectManual => '$baseUrl/qr/connect-manual';
  static String get verifyQR => '$baseUrl/qr/verify';
  static String get verifyManual => '$baseUrl/qr/verify-manual';

  // ── SOS ────────────────────────────────────────────────────────────
  static String get triggerSos => '$baseUrl/sos';
  static String get sosHistory => '$baseUrl/sos/history';
  static String acknowledgeSos(String sosId) =>
      '$baseUrl/sos/$sosId/acknowledge';

  // ── Location ───────────────────────────────────────────────────────
  static String elderlyLocation(String elderlyId) => '$baseUrl/elderly/$elderlyId/location';

  // ── Safe Zone (Geofencing) ─────────────────────────────────────────
  static String safeZone(String elderlyId) => '$baseUrl/elderly/$elderlyId/safe-zone';

  // ── Events / Notifications ────────────────────────────────────────────
  static String get caregiverNotifications => '$baseUrl/events/notifications';
  static String eventsTodayStats(String elderlyId) => '$baseUrl/events/today-stats/$elderlyId';
  static String eventsForElderly(String elderlyId) => '$baseUrl/events/$elderlyId';

  // ── Voice Messages ─────────────────────────────────────────────────
  static String get voiceMessages => '$baseUrl/voice-messages';
  static String voiceMessageById(String id) => '$baseUrl/voice-messages/$id';
  static String voiceMessageSend(String id) => '$baseUrl/voice-messages/$id/send';
  static String voiceMessagesForElder(String elderlyId) => '$baseUrl/voice-messages/elder/$elderlyId';

  // ── Pillbox ────────────────────────────────────────────────────────
  static String pillboxSlots(String elderlyId) => '$baseUrl/pillbox/slots/$elderlyId';
  static String pillboxSlot(String elderlyId, int slotNumber) =>
      '$baseUrl/pillbox/slots/$elderlyId/$slotNumber';
  static String get pillboxSchedules => '$baseUrl/pillbox/schedules';
  static String pillboxScheduleById(String scheduleId) =>
      '$baseUrl/pillbox/schedules/$scheduleId';
  static String pillboxLogs(String elderlyId) => '$baseUrl/pillbox/logs/$elderlyId';
  static String pillboxToday(String elderlyId) => '$baseUrl/pillbox/today/$elderlyId';

  // ── Messages (elder → caregiver preset messages) ──────────────────
  static String get sendPresetMessage => '$baseUrl/messages/preset';
  static String get caregiverMessages => '$baseUrl/messages';
  static String messageMarkRead(String id) => '$baseUrl/messages/$id/read';
  static String get messagesUnreadCount => '$baseUrl/messages/unread-count';

  // ── Reports ────────────────────────────────────────────────────────
  static String weeklyReport(String elderlyId) => '$baseUrl/reports/weekly/$elderlyId';

  // ── Timeouts ───────────────────────────────────────────────────────
  static const Duration timeout = Duration(seconds: 15);
}
