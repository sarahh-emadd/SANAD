import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/location_model.dart';
import 'api_service.dart';

class LocationService {
  /// Caregiver: fetch the last known location of an elderly person.
  static Future<LocationModel> getElderLocation(String elderlyId) async {
    final res = await ApiService.get(ApiConfig.elderlyLocation(elderlyId));
    return LocationModel.fromJson(
        res['data']['location'] as Map<String, dynamic>);
  }

  /// Elder app: get GPS and push to backend.
  /// Tries medium accuracy first, then falls back to low accuracy.
  /// On simulator, uses a default coordinate so demos work without real GPS.
  static Future<bool> reportLocation(String elderlyId,
      {int? batteryLevel}) async {
    try {
      // ── 1. Permission check ─────────────────────────────────────────
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[Location] Permission denied — cannot report location');
        return false;
      }

      // ── 2. Try to get GPS (medium → low accuracy fallback) ──────────
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        // Medium accuracy timed out — try lower accuracy (works better on simulator)
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 6),
            ),
          );
        } catch (_) {
          // GPS completely unavailable (no simulator location set, no real GPS)
          debugPrint('[Location] GPS unavailable — skipping update');
          return false;
        }
      }

      // ── 3. Push to backend ──────────────────────────────────────────
      final res = await http.put(
        Uri.parse(ApiConfig.elderlyLocation(elderlyId)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'address': '',
          'is_home': false,
          if (batteryLevel != null) 'battery_level': batteryLevel,
        }),
      ).timeout(ApiConfig.timeout);

      final ok = res.statusCode == 200 || res.statusCode == 201;
      debugPrint(
          '[Location] Reported: ${pos.latitude.toStringAsFixed(4)}, '
          '${pos.longitude.toStringAsFixed(4)} → ${ok ? '✅' : '❌ ${res.statusCode}'}');
      return ok;
    } catch (e) {
      debugPrint('[Location] reportLocation error: $e');
      return false;
    }
  }
}
