import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../models/voice_reminder_model.dart';

class VoiceReminderService {
  static Future<String?> _token() async =>
      await FirebaseAuth.instance.currentUser?.getIdToken();

  // ── Caregiver: list saved messages ──────────────────────────────────────
  static Future<List<VoiceReminder>> listMessages() async {
    final token = await _token();
    final res = await http.get(
      Uri.parse(ApiConfig.voiceMessages),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(ApiConfig.timeout);
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) throw Exception(body['message'] ?? 'Failed to load messages');
    final list = body['data']['messages'] as List;
    return list.map((m) => VoiceReminder.fromJson(m as Map<String, dynamic>)).toList();
  }

  // ── Caregiver: upload a new voice message ────────────────────────────────
  // isSaved = true  → appears in caregiver's library (Save & Send)
  // isSaved = false → sent once, hidden from library (Send Once)
  static Future<VoiceReminder> uploadMessage({
    required String title,
    required String elderlyId,
    required File audioFile,
    int durationSecs = 0,
    bool isSaved = true,
  }) async {
    final token = await _token();
    final req = http.MultipartRequest('POST', Uri.parse(ApiConfig.voiceMessages))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['title']         = title
      ..fields['elderly_id']    = elderlyId
      ..fields['duration_secs'] = durationSecs.toString()
      ..fields['is_saved']      = isSaved.toString()
      ..files.add(await http.MultipartFile.fromPath('audio', audioFile.path,
          filename: '${DateTime.now().millisecondsSinceEpoch}.m4a'));

    final streamed = await req.send().timeout(ApiConfig.timeout);
    final res = await http.Response.fromStream(streamed);
    final body = jsonDecode(res.body);
    if (res.statusCode != 201) throw Exception(body['message'] ?? 'Upload failed');
    return VoiceReminder.fromJson(body['data']['message'] as Map<String, dynamic>);
  }

  // ── Caregiver: send a message to elder (triggers socket event) ───────────
  static Future<void> sendMessage(String messageId) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse(ApiConfig.voiceMessageSend(messageId)),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(ApiConfig.timeout);
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Send failed');
    }
  }

  // ── Caregiver: delete a message ─────────────────────────────────────────
  static Future<void> deleteMessage(String messageId) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConfig.voiceMessageById(messageId)),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(ApiConfig.timeout);
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Delete failed');
    }
  }

  // ── Elder: list messages received ───────────────────────────────────────
  static Future<List<VoiceReminder>> listElderMessages(String elderlyId) async {
    final res = await http.get(
      Uri.parse(ApiConfig.voiceMessagesForElder(elderlyId)),
      headers: {'Content-Type': 'application/json'},
    ).timeout(ApiConfig.timeout);
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) throw Exception(body['message'] ?? 'Failed');
    final list = body['data']['messages'] as List;
    return list.map((m) => VoiceReminder.fromJson(m as Map<String, dynamic>)).toList();
  }
}
