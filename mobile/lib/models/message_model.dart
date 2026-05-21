// ════════════════════════════════════════════════════════════
//  MESSAGE MODEL
//  Used by: HomeElderPage
// ════════════════════════════════════════════════════════════

class VoiceMessage {
  final String id;
  final String fromName;
  final String fromId;
  final String duration;
  final String timeAgo;
  final bool isPlaying;
  final bool isRead;
  final DateTime createdAt;

  const VoiceMessage({
    required this.id,
    required this.fromName,
    required this.fromId,
    required this.duration,
    required this.timeAgo,
    this.isPlaying = false,
    this.isRead    = false,
    required this.createdAt,
  });

  factory VoiceMessage.fromJson(Map<String, dynamic> json) {
    return VoiceMessage(
      id:        json['id']?.toString() ?? '',
      fromName:  json['from_name'] as String? ?? '',
      fromId:    json['from_id']?.toString() ?? '',
      duration:  json['duration'] as String? ?? '0:00',
      timeAgo:   json['time_ago'] as String? ?? '',
      isPlaying: false,
      isRead:    json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  VoiceMessage copyWith({bool? isPlaying, bool? isRead}) {
    return VoiceMessage(
      id:        id,
      fromName:  fromName,
      fromId:    fromId,
      duration:  duration,
      timeAgo:   timeAgo,
      isPlaying: isPlaying ?? this.isPlaying,
      isRead:    isRead    ?? this.isRead,
      createdAt: createdAt,
    );
  }
}