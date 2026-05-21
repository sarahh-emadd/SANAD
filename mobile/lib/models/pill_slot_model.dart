// lib/models/pill_slot_model.dart

enum SlotTakenStatus { taken, missed, scheduled }

class PillSlot {
  String label;
  int hour;
  int minute;
  int reminderAfterMins;
  SlotTakenStatus status;

  PillSlot({
    required this.label,
    required this.hour,
    required this.minute,
    required this.reminderAfterMins,
    required this.status,
  });

  /// Factory: default scheduled slot
  factory PillSlot.empty() => PillSlot(
    label: 'New Slot',
    hour: 12,
    minute: 0,
    reminderAfterMins: 30,
    status: SlotTakenStatus.scheduled,
  );

  /// Copy with override
  PillSlot copyWith({
    String? label,
    int? hour,
    int? minute,
    int? reminderAfterMins,
    SlotTakenStatus? status,
  }) =>
      PillSlot(
        label: label ?? this.label,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        reminderAfterMins: reminderAfterMins ?? this.reminderAfterMins,
        status: status ?? this.status,
      );
}

class DaySchedule {
  final String dayName;
  final List<PillSlot> slots;

  DaySchedule({required this.dayName, required this.slots});
}