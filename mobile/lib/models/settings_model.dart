// ════════════════════════════════════════════════════════════
//  SETTINGS MODEL
//  Used by: CaregiverSettingsScreen, ElderSettingsScreen
// ════════════════════════════════════════════════════════════

// ── Enums ───────────────────────────────────────────────────
enum VolumeLevel { low, medium, high }

enum TextSizeOption { large, medium, small }

// ── Notification Preferences ────────────────────────────────
class NotificationPrefs {
  final bool messages;
  final bool reminder;
  final bool activity;
  final bool camera;
  final bool medication;

  const NotificationPrefs({
    this.messages   = true,
    this.reminder   = true,
    this.activity   = true,
    this.camera     = true,
    this.medication = true,
  });

  bool get allEnabled =>
      messages && reminder && activity && camera && medication;

  NotificationPrefs copyWith({
    bool? messages,
    bool? reminder,
    bool? activity,
    bool? camera,
    bool? medication,
  }) {
    return NotificationPrefs(
      messages:   messages   ?? this.messages,
      reminder:   reminder   ?? this.reminder,
      activity:   activity   ?? this.activity,
      camera:     camera     ?? this.camera,
      medication: medication ?? this.medication,
    );
  }

  Map<String, dynamic> toJson() => {
    'messages':   messages,
    'reminder':   reminder,
    'activity':   activity,
    'camera':     camera,
    'medication': medication,
  };

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    return NotificationPrefs(
      messages:   json['messages']   as bool? ?? true,
      reminder:   json['reminder']   as bool? ?? true,
      activity:   json['activity']   as bool? ?? true,
      camera:     json['camera']     as bool? ?? true,
      medication: json['medication'] as bool? ?? true,
    );
  }
}

// ── App Settings Model ───────────────────────────────────────
class AppSettings {
  final VolumeLevel volume;
  final TextSizeOption textSize;
  final NotificationPrefs notifications;

  const AppSettings({
    this.volume        = VolumeLevel.high,
    this.textSize      = TextSizeOption.large,
    this.notifications = const NotificationPrefs(),
  });

  String get volumeLabel {
    switch (volume) {
      case VolumeLevel.low:    return 'Low';
      case VolumeLevel.medium: return 'Medium';
      case VolumeLevel.high:   return 'High';
    }
  }

  double get volumeSliderValue {
    switch (volume) {
      case VolumeLevel.low:    return 0.0;
      case VolumeLevel.medium: return 0.5;
      case VolumeLevel.high:   return 1.0;
    }
  }

  static VolumeLevel volumeFromSlider(double value) {
    if (value <= 0.25) return VolumeLevel.low;
    if (value <= 0.65) return VolumeLevel.medium;
    return VolumeLevel.high;
  }

  String get textSizeLabel {
    switch (textSize) {
      case TextSizeOption.large:  return 'Large Mode';
      case TextSizeOption.medium: return 'Medium';
      case TextSizeOption.small:  return 'Small';
    }
  }

  static TextSizeOption textSizeFromLabel(String label) {
    switch (label) {
      case 'Medium': return TextSizeOption.medium;
      case 'Small':  return TextSizeOption.small;
      default:       return TextSizeOption.large;
    }
  }

  AppSettings copyWith({
    VolumeLevel?       volume,
    TextSizeOption?    textSize,
    NotificationPrefs? notifications,
  }) {
    return AppSettings(
      volume:        volume        ?? this.volume,
      textSize:      textSize      ?? this.textSize,
      notifications: notifications ?? this.notifications,
    );
  }

  Map<String, dynamic> toJson() => {
    'volume':        volume.index,
    'text_size':     textSize.index,
    'notifications': notifications.toJson(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final volumeIndex   = json['volume'] as int? ?? 2;
    final textSizeIndex = json['text_size'] as int? ?? 0;
    return AppSettings(
      volume:    VolumeLevel.values[volumeIndex.clamp(0, VolumeLevel.values.length - 1)],
      textSize:  TextSizeOption.values[textSizeIndex.clamp(0, TextSizeOption.values.length - 1)],
      notifications: json['notifications'] != null
          ? NotificationPrefs.fromJson(
          Map<String, dynamic>.from(json['notifications'] as Map))
          : const NotificationPrefs(),
    );
  }
}