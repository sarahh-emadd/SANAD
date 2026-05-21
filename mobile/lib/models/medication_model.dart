// ════════════════════════════════════════════════════════════
//  MEDICATION MODEL
//  Used by: HomeElderPage, CaregiverHomeScreen,
//           MedicationHistoryScreen, PillBoxAlertHistoryScreen
// ════════════════════════════════════════════════════════════

// ── Enums ───────────────────────────────────────────────────
enum SlotStatus { taken, dueSoon, scheduled, missed }

enum AlertType { danger, warning, success }

// ── Slot Model ──────────────────────────────────────────────
class MedicationSlot {
  final String id;
  final String label;
  final String time;
  final String statusLabel;
  final SlotStatus status;
  final List<String> medications;

  const MedicationSlot({
    required this.id,
    required this.label,
    required this.time,
    required this.statusLabel,
    required this.status,
    this.medications = const [],
  });

  factory MedicationSlot.fromJson(Map<String, dynamic> json) {
    return MedicationSlot(
      id:          json['id']?.toString() ?? '',
      label:       json['label'] as String? ?? '',
      time:        json['time'] as String? ?? '',
      statusLabel: json['status_label'] as String? ?? '',
      status:      _parseStatus(json['status'] as String?),
      medications: List<String>.from(json['medications'] as List? ?? []),
    );
  }

  static SlotStatus _parseStatus(String? s) {
    switch (s) {
      case 'taken':     return SlotStatus.taken;
      case 'due_soon':  return SlotStatus.dueSoon;
      case 'missed':    return SlotStatus.missed;
      default:          return SlotStatus.scheduled;
    }
  }
}

// ── Medication Alert Model ───────────────────────────────────
class MedicationAlert {
  final String id;
  final String title;
  final String subtitle;
  final String detail;
  final AlertType type;
  final DateTime timestamp;

  const MedicationAlert({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.type,
    required this.timestamp,
  });

  factory MedicationAlert.fromJson(Map<String, dynamic> json) {
    return MedicationAlert(
      id:        json['id']?.toString() ?? '',
      title:     json['title'] as String? ?? '',
      subtitle:  json['subtitle'] as String? ?? '',
      detail:    json['detail'] as String? ?? '',
      type:      _parseType(json['type'] as String?),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static AlertType _parseType(String? t) {
    switch (t) {
      case 'warning': return AlertType.warning;
      case 'success': return AlertType.success;
      default:        return AlertType.danger;
    }
  }
}

// ── Medication Summary Model ─────────────────────────────────
class MedicationSummary {
  final int taken;
  final int total;
  final double adherencePercent;

  const MedicationSummary({
    required this.taken,
    required this.total,
    required this.adherencePercent,
  });

  String get label => '$taken / $total';

  factory MedicationSummary.fromJson(Map<String, dynamic> json) {
    return MedicationSummary(
      taken:            json['taken'] as int? ?? 0,
      total:            json['total'] as int? ?? 0,
      adherencePercent: (json['adherence_percent'] as num? ?? 0.0).toDouble(),
    );
  }
}