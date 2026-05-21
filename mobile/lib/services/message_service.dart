// ════════════════════════════════════════════════════════════
//  MESSAGE SERVICE
//  Currently: returns mock data
//  When backend ready: replace mock methods with ApiService calls
// ════════════════════════════════════════════════════════════

import '../models/message_model.dart';
// TODO: uncomment when backend endpoints are ready
// import 'api_service.dart';
// import '../config/api_config.dart';

class MessageService {
  // ── Get voice messages ───────────────────────────────
  /// Returns list of voice messages for the elder.
  /// 🔁 Replace mock with:
  ///    final res = await ApiService.get(ApiConfig.getMessages);
  ///    return (res['data']['messages'] as List).map(VoiceMessage.fromJson).toList();
  static Future<List<VoiceMessage>> getMessages() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockMessages;
  }

  // ── Mark message as read ─────────────────────────────
  /// 🔁 Replace mock with:
  ///    await ApiService.put(ApiConfig.markMessageRead(id), {});
  static Future<void> markAsRead(String messageId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // mock: no-op
  }

  // ════════════════════════════════════════════════════
  //  MOCK DATA — delete when backend is ready
  // ════════════════════════════════════════════════════

  static final List<VoiceMessage> _mockMessages = [
    VoiceMessage(
      id:        'm1',
      fromName:  'Olivia',
      fromId:    'caregiver_1',
      duration:  '0:35',
      timeAgo:   '2 min ago',
      isRead:    false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
  ];
}