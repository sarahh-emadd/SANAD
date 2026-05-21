// ════════════════════════════════════════════════════════════
//  MEDICATION SERVICE
//  Currently: returns mock data
//  When backend ready: replace mock methods with ApiService calls
// ════════════════════════════════════════════════════════════

import '../models/medication_model.dart';
// TODO: uncomment when backend endpoints are ready
// import 'api_service.dart';
// import '../config/api_config.dart';

class MedicationService {
  // ── Get today's slots ────────────────────────────────
  /// Returns the pill slots for today.
  /// 🔁 Replace mock with:
  ///    final res = await ApiService.get(ApiConfig.getMedicationSlots);
  ///    return (res['data']['slots'] as List).map(MedicationSlot.fromJson).toList();
  static Future<List<MedicationSlot>> getTodaySlots() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _mockSlots;
  }

  // ── Get today's alerts ───────────────────────────────
  /// Returns pillbox alerts (missed, refill, taken).
  /// 🔁 Replace mock with:
  ///    final res = await ApiService.get(ApiConfig.getMedicationAlerts);
  ///    return (res['data']['alerts'] as List).map(MedicationAlert.fromJson).toList();
  static Future<List<MedicationAlert>> getTodayAlerts() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _mockAlerts;
  }

  // ── Get summary ──────────────────────────────────────
  /// Returns taken/total count and adherence %.
  /// 🔁 Replace mock with:
  ///    final res = await ApiService.get(ApiConfig.getMedicationSummary);
  ///    return MedicationSummary.fromJson(res['data']['summary']);
  static Future<MedicationSummary> getTodaySummary() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _mockSummary;
  }

  // ── Get slot history grouped by date ─────────────────
  /// Returns a map of date label → list of slots (for History screens).
  /// 🔁 Replace mock with:
  ///    final res = await ApiService.get(ApiConfig.getMedicationHistory);
  ///    // backend returns { "data": { "today": [...], "yesterday": [...], ... } }
  ///    return _parseGroupedSlots(res['data']);
  static Future<Map<String, List<MedicationSlot>>> getSlotHistory() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _mockSlotHistory;
  }

  // ── Get alert history grouped by date ────────────────
  /// Returns a map of date label → list of alerts (for PillBoxAlertHistory).
  /// 🔁 Replace mock with:
  ///    final res = await ApiService.get(ApiConfig.getAlertHistory);
  ///    return _parseGroupedAlerts(res['data']);
  static Future<Map<String, List<MedicationAlert>>> getAlertHistory() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _mockAlertHistory;
  }

  // ════════════════════════════════════════════════════
  //  MOCK DATA — delete when backend is ready
  // ════════════════════════════════════════════════════

  static final List<MedicationSlot> _mockSlots = [
    const MedicationSlot(
      id:          '1',
      label:       'Slot 1',
      time:        '8:00 AM',
      statusLabel: 'Taken',
      status:      SlotStatus.taken,
      medications: ['Aspirin 100mg'],
    ),
    const MedicationSlot(
      id:          '2',
      label:       'Slot 2',
      time:        '12:00 PM',
      statusLabel: 'Due Soon',
      status:      SlotStatus.dueSoon,
      medications: ['Metformin 500mg'],
    ),
    const MedicationSlot(
      id:          '3',
      label:       'Slot 3',
      time:        '8:00 PM',
      statusLabel: 'Scheduled',
      status:      SlotStatus.scheduled,
      medications: ['Vitamin D'],
    ),
  ];

  static final List<MedicationAlert> _mockAlerts = [
    MedicationAlert(
      id:        'a1',
      title:     'Missed Dose',
      subtitle:  'from Slot 2',
      detail:    '12:00 PM  •  missed from 30 mins ago',
      type:      AlertType.danger,
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    MedicationAlert(
      id:        'a2',
      title:     'Refill Needed',
      subtitle:  'Slot 1 is Empty',
      detail:    '',
      type:      AlertType.warning,
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    MedicationAlert(
      id:        'a3',
      title:     'Taken',
      subtitle:  'from Slot 1',
      detail:    '8:00 AM  •  Taken from 30 mins ago',
      type:      AlertType.success,
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  static const MedicationSummary _mockSummary = MedicationSummary(
    taken:            2,
    total:            3,
    adherencePercent: 0.89,
  );

  // ── Mock grouped slot history ─────────────────────────
  static final Map<String, List<MedicationSlot>> _mockSlotHistory = {
    'Today': [
      const MedicationSlot(
        id: 'h1', label: 'Slot 1', time: '8:00 AM',
        statusLabel: 'Taken', status: SlotStatus.taken,
        medications: ['Aspirin 100mg'],
      ),
      const MedicationSlot(
        id: 'h2', label: 'Slot 2', time: '12:00 PM',
        statusLabel: 'Missed', status: SlotStatus.missed,
        medications: ['Metformin 500mg'],
      ),
      const MedicationSlot(
        id: 'h3', label: 'Slot 3', time: '8:00 PM',
        statusLabel: 'Scheduled', status: SlotStatus.scheduled,
        medications: ['Vitamin D'],
      ),
    ],
    'Yesterday': [
      const MedicationSlot(
        id: 'h4', label: 'Slot 1', time: '8:00 AM',
        statusLabel: 'Taken', status: SlotStatus.taken,
        medications: ['Aspirin 100mg'],
      ),
      const MedicationSlot(
        id: 'h5', label: 'Slot 2', time: '12:00 PM',
        statusLabel: 'Taken', status: SlotStatus.taken,
        medications: ['Metformin 500mg'],
      ),
      const MedicationSlot(
        id: 'h6', label: 'Slot 3', time: '8:00 PM',
        statusLabel: 'Taken', status: SlotStatus.taken,
        medications: ['Vitamin D'],
      ),
    ],
    'Nov 12': [
      const MedicationSlot(
        id: 'h7', label: 'Slot 1', time: '8:00 AM',
        statusLabel: 'Taken', status: SlotStatus.taken,
        medications: ['Aspirin 100mg'],
      ),
      const MedicationSlot(
        id: 'h8', label: 'Slot 2', time: '12:00 PM',
        statusLabel: 'Missed', status: SlotStatus.missed,
        medications: ['Metformin 500mg'],
      ),
      const MedicationSlot(
        id: 'h9', label: 'Slot 3', time: '8:00 PM',
        statusLabel: 'Taken', status: SlotStatus.taken,
        medications: ['Vitamin D'],
      ),
    ],
  };

  // ── Mock grouped alert history ────────────────────────
  static final Map<String, List<MedicationAlert>> _mockAlertHistory = {
    'Today': [
      MedicationAlert(
        id: 'ah1', title: 'Missed Dose', subtitle: 'from Slot 2',
        detail: '12:00 PM  •  missed from 30 mins ago',
        type: AlertType.danger,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      MedicationAlert(
        id: 'ah2', title: 'Refill Needed', subtitle: 'Slot 1 is Empty',
        detail: '',
        type: AlertType.warning,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      MedicationAlert(
        id: 'ah3', title: 'Taken', subtitle: 'from Slot 1',
        detail: '8:00 AM  •  Taken on time',
        type: AlertType.success,
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      ),
    ],
    'Yesterday': [
      MedicationAlert(
        id: 'ah4', title: 'Taken', subtitle: 'from Slot 1',
        detail: '8:00 AM  •  Taken on time',
        type: AlertType.success,
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      ),
      MedicationAlert(
        id: 'ah5', title: 'Taken', subtitle: 'from Slot 2',
        detail: '12:00 PM  •  Taken on time',
        type: AlertType.success,
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 12)),
      ),
      MedicationAlert(
        id: 'ah6', title: 'Taken', subtitle: 'from Slot 3',
        detail: '8:00 PM  •  Taken 10 mins ago',
        type: AlertType.success,
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 20)),
      ),
    ],
    'Nov 12': [
      MedicationAlert(
        id: 'ah7', title: 'Missed Dose', subtitle: 'from Slot 2',
        detail: '12:00 PM  •  missed from 1 hour ago',
        type: AlertType.danger,
        timestamp: DateTime(2024, 11, 12, 13, 0),
      ),
      MedicationAlert(
        id: 'ah8', title: 'Refill Needed', subtitle: 'Slot 3 is Low',
        detail: '',
        type: AlertType.warning,
        timestamp: DateTime(2024, 11, 12, 10, 0),
      ),
      MedicationAlert(
        id: 'ah9', title: 'Taken', subtitle: 'from Slot 1',
        detail: '8:00 AM  •  Taken on time',
        type: AlertType.success,
        timestamp: DateTime(2024, 11, 12, 8, 0),
      ),
    ],
  };
}