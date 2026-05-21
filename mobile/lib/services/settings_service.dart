// ════════════════════════════════════════════════════════════
//  SETTINGS SERVICE
//  Saves/loads AppSettings from SharedPreferences locally
// ════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';

class SettingsService {
  static const _keySettings = 'sanad_app_settings';

  // ── Load settings ────────────────────────────────────
  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final str   = prefs.getString(_keySettings);
    if (str == null) return const AppSettings();
    try {
      return AppSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(str) as Map));
    } catch (_) {
      return const AppSettings();
    }
  }

  // ── Save settings ────────────────────────────────────
  static Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySettings, jsonEncode(settings.toJson()));
  }

  // ── Update volume only ───────────────────────────────
  static Future<AppSettings> updateVolume(
      AppSettings current,
      VolumeLevel volume,
      ) async {
    final updated = current.copyWith(volume: volume);
    await save(updated);
    return updated;
  }

  // ── Update text size only ────────────────────────────
  static Future<AppSettings> updateTextSize(
      AppSettings current,
      TextSizeOption textSize,
      ) async {
    final updated = current.copyWith(textSize: textSize);
    await save(updated);
    return updated;
  }

  // ── Update notifications only ────────────────────────
  static Future<AppSettings> updateNotifications(
      AppSettings current,
      NotificationPrefs notifs,
      ) async {
    final updated = current.copyWith(notifications: notifs);
    await save(updated);
    return updated;
  }

  // ── Reset to defaults ────────────────────────────────
  static Future<AppSettings> reset() async {
    const defaults = AppSettings();
    await save(defaults);
    return defaults;
  }
}