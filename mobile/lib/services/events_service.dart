import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class EventModel {
  final String id;
  final String elderlyId;
  final String elderlyName;
  final String eventType;
  final double confidence;
  final String? snapshotUrl;
  final bool verified;
  final bool isFalsePositive;
  final bool alertSent;
  final DateTime createdAt;

  EventModel({
    required this.id,
    required this.elderlyId,
    required this.elderlyName,
    required this.eventType,
    required this.confidence,
    this.snapshotUrl,
    required this.verified,
    required this.isFalsePositive,
    required this.alertSent,
    required this.createdAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> j) => EventModel(
        id: j['id'] as String,
        elderlyId: j['elderly_id'] as String,
        elderlyName: j['elderly_name'] as String? ?? '',
        eventType: j['event_type'] as String,
        confidence: (j['confidence'] as num).toDouble(),
        snapshotUrl: j['snapshot_url'] as String?,
        verified: j['verified'] as bool? ?? false,
        isFalsePositive: j['is_false_positive'] as bool? ?? false,
        alertSent: j['alert_sent'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  // Human-readable title for the event type
  String get title {
    switch (eventType) {
      case 'fall':
        return 'Fall Detected';
      case 'inactivity':
        return 'Inactivity Alert';
      case 'sleeping':
        return 'Sleeping Alert';
      default:
        return 'Alert';
    }
  }

  // Confidence as percentage string e.g. "90%"
  String get confidencePercent => '${(confidence * 100).round()}%';

  // Time ago string relative to now
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24)
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
  }
}

class TodayStats {
  final int falls;
  final int inactivity;
  final int sleeping;
  final int total;

  TodayStats({
    required this.falls,
    required this.inactivity,
    required this.sleeping,
    required this.total,
  });

  String get activityLevel {
    if (falls > 0) return 'Danger';
    if (inactivity > 2) return 'Low';
    if (total == 0) return 'Normal';
    return 'Normal';
  }
}

class EventsService {
  static Future<String?> _token() async {
    final user = FirebaseAuth.instance.currentUser;
    return await user?.getIdToken();
  }

  /// GET /api/v1/events/:elderlyId — events for one elderly, newest first
  static Future<List<EventModel>> getEventsByElderly(
    String elderlyId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final token = await _token();
    if (token == null) return [];

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/events/$elderlyId?limit=$limit&offset=$offset',
    );
    final res = await http.get(uri,
        headers: {'Authorization': 'Bearer $token'}).timeout(ApiConfig.timeout);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body)['data']['events'] as List;
      return data.map((e) => EventModel.fromJson(e)).toList();
    }
    return [];
  }

  /// GET /api/v1/events/unverified — all unverified events for this caregiver
  static Future<List<EventModel>> getUnverifiedEvents() async {
    final token = await _token();
    if (token == null) return [];

    final uri = Uri.parse('${ApiConfig.baseUrl}/events/unverified');
    final res = await http.get(uri,
        headers: {'Authorization': 'Bearer $token'}).timeout(ApiConfig.timeout);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body)['data']['events'] as List;
      return data.map((e) => EventModel.fromJson(e)).toList();
    }
    return [];
  }

  /// GET /api/v1/events/detail/:eventId
  static Future<EventModel?> getEventById(String eventId) async {
    final token = await _token();
    if (token == null) return null;

    final uri = Uri.parse('${ApiConfig.baseUrl}/events/detail/$eventId');
    final res = await http.get(uri,
        headers: {'Authorization': 'Bearer $token'}).timeout(ApiConfig.timeout);

    if (res.statusCode == 200) {
      return EventModel.fromJson(jsonDecode(res.body)['data']['event']);
    }
    return null;
  }

  /// PUT /api/v1/events/:eventId/verify
  static Future<bool> verifyEvent(String eventId,
      {bool isFalsePositive = false}) async {
    final token = await _token();
    if (token == null) return false;

    final uri = Uri.parse('${ApiConfig.baseUrl}/events/$eventId/verify');
    final res = await http
        .put(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'is_false_positive': isFalsePositive}),
        )
        .timeout(ApiConfig.timeout);

    return res.statusCode == 200;
  }

  /// Build TodayStats from a list of today's events
  static TodayStats buildTodayStats(List<EventModel> events) {
    final today = DateTime.now();
    final todayEvents = events
        .where((e) =>
            e.createdAt.year == today.year &&
            e.createdAt.month == today.month &&
            e.createdAt.day == today.day &&
            !e.isFalsePositive)
        .toList();

    final falls = todayEvents.where((e) => e.eventType == 'fall').length;
    final inactivity =
        todayEvents.where((e) => e.eventType == 'inactivity').length;
    final sleeping = todayEvents.where((e) => e.eventType == 'sleeping').length;

    return TodayStats(
      falls: falls,
      inactivity: inactivity,
      sleeping: sleeping,
      total: falls + inactivity + sleeping,
    );
  }
}
