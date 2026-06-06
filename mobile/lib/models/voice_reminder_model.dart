class VoiceReminder {
  final String id;
  final String title;
  final String filePath;
  final int usedTimes;
  final int durationSecs;
  final String lastUsed;
  final DateTime createdAt;

  const VoiceReminder({
    required this.id,
    required this.title,
    required this.filePath,
    required this.usedTimes,
    required this.durationSecs,
    required this.lastUsed,
    required this.createdAt,
  });

  factory VoiceReminder.fromJson(Map<String, dynamic> json) => VoiceReminder(
        id:           json['id'] as String,
        title:        json['title'] as String,
        filePath:     json['file_path'] as String,
        usedTimes:    (json['used_times']    as num?)?.toInt() ?? 0,
        durationSecs: (json['duration_secs'] as num?)?.toInt() ?? 0,
        lastUsed:     json['last_used'] as String? ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id':            id,
        'title':         title,
        'file_path':     filePath,
        'duration_secs': durationSecs,
        'created_at':    createdAt.toIso8601String(),
      };
}
