// lib/services/sos_service.dart
//
// Handles SOS HTTP call and socket acknowledgement.
// Follows the exact pattern of events_service.dart.

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class SosModel {
  final String id;
  final String elderlyId;
  final String? elderlyName;
  final String status;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;

  SosModel({
    required this.id,
    required this.elderlyId,
    this.elderlyName,
    required this.status,
    required this.createdAt,
    this.acknowledgedAt,
  });

  factory SosModel.fromJson(Map<String, dynamic> j) => SosModel(
        id:             j['id'] as String,
        elderlyId:      j['elderly_id'] as String,
        elderlyName:    j['elderly_name'] as String?,
        status:         j['status'] as String? ?? 'pending',
        createdAt:      DateTime.parse(j['created_at'] as String),
        acknowledgedAt: j['acknowledged_at'] != null
            ? DateTime.parse(j['acknowledged_at'] as String)
            : null,
      );

  bool get isPending      => status == 'pending';
  bool get isAcknowledged => status == 'acknowledged';

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
  }
}

class SosService {
  static Future<String?> _token() async =>
      await FirebaseAuth.instance.currentUser?.getIdToken();

  // ── Elder: trigger SOS ────────────────────────────────────────────────────

  /// Called when the elder presses the SOS button.
  /// [elderlyId] is the UUID from the database (stored locally after QR connect).
  /// Returns the new SOS id on success, null on failure.
  /// [source] is 'manual' (button press) or 'auto_fall' (accelerometer detected).
  static Future<String?> triggerSos(String elderlyId,
      {String source = 'manual'}) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/sos');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'elderly_id': elderlyId, 'source': source}),
          )
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body)['data'];
        return data['sos_id'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Caregiver: acknowledge SOS via REST (persists to DB) ─────────────────

  /// Called after caregiver taps "I'm on my way".
  /// Also emit 'sos_acknowledged' via socket for instant feedback to the elder.
  static Future<bool> acknowledgeSos(String sosId) async {
    final token = await _token();
    if (token == null) return false;

    final uri = Uri.parse('${ApiConfig.baseUrl}/sos/$sosId/acknowledge');
    final res = await http
        .put(
          uri,
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(ApiConfig.timeout);

    return res.statusCode == 200;
  }

  // ── Caregiver: SOS history ────────────────────────────────────────────────

  static Future<List<SosModel>> getSosHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final token = await _token();
    if (token == null) return [];

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/sos/history?limit=$limit&offset=$offset',
    );
    final res = await http
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(ApiConfig.timeout);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body)['data']['history'] as List;
      return data.map((e) => SosModel.fromJson(e)).toList();
    }
    return [];
  }
}
