import 'package:flutter/material.dart';

// ── Models ─────────────────────────────────────────────────────────────────────

enum SlotTakenStatus { taken, missed, scheduled }

class PillSlot {
  String label;
  TimeOfDay time;
  int reminderAfterMins;
  SlotTakenStatus status;

  PillSlot({
    required this.label,
    required this.time,
    required this.reminderAfterMins,
    required this.status,
  });
}

class DaySchedule {
  final String dayName;
  final List<PillSlot> slots;

  DaySchedule({required this.dayName, required this.slots});
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class ManagePillsScreen extends StatefulWidget {
  const ManagePillsScreen({super.key});

  @override
  State<ManagePillsScreen> createState() => _ManagePillsScreenState();
}

class _ManagePillsScreenState extends State<ManagePillsScreen> {
  // ── Colors ──────────────────────────────────────────────────────────────────
  static const primary    = Color(0xFF2FA884);
  static const primaryBg  = Color(0xFFE6F4F0);
  static const okGreen    = Color(0xFF388E3C);
  static const lightGreen = Color(0xFFEEF7EE);
  static const dangerRed  = Color(0xFFE53935);
  static const lightRed   = Color(0xFFFFF0EE);
  static const bgColor    = Color(0xFFF5F7F6);
  static const textDark   = Color(0xFF1A1A1A);
  static const textGrey   = Color(0xFFAAAAAA);
  static const cardBorder = Color(0xFFEEEEEE);

  static TextStyle m(double size, FontWeight weight, Color color) =>
      TextStyle(fontFamily: 'Montserrat', fontSize: size, fontWeight: weight, color: color);

  // ── Label Options ────────────────────────────────────────────────────────────
  static const List<String> _labelOptions = [
    'Before Breakfast',
    'After Breakfast',
    'Before Lunch',
    'After Lunch',
    'Before Dinner',
    'After Dinner',
    'Before Sleep',
    'Empty Stomach',
    'With Water',
  ];

  // ── State ───────────────────────────────────────────────────────────────────
  final List<String> _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  int _selectedDayIndex = 6;

  late final List<DaySchedule> _weekData = List.generate(7, (i) {
    return DaySchedule(
      dayName: _days[i],
      slots: [
        PillSlot(label: 'After Lunch',  time: const TimeOfDay(hour: 8, minute: 0),  reminderAfterMins: 30, status: SlotTakenStatus.taken),
        PillSlot(label: 'After Lunch',  time: const TimeOfDay(hour: 8, minute: 0),  reminderAfterMins: 30, status: SlotTakenStatus.taken),
        PillSlot(label: 'After Dinner', time: const TimeOfDay(hour: 20, minute: 0), reminderAfterMins: 30, status: SlotTakenStatus.scheduled),
      ],
    );
  });

  DaySchedule get _currentDay => _weekData[_selectedDayIndex];

  // ── Helpers ──────────────────────────────────────────────────────────────────
  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$min $period';
  }

  IconData _getIconForLabel(String label) {
    if (label.contains('Breakfast')) return Icons.wb_sunny_outlined;
    if (label.contains('Lunch'))     return Icons.light_mode_outlined;
    if (label.contains('Dinner'))    return Icons.nights_stay_outlined;
    if (label.contains('Sleep'))     return Icons.bedtime_outlined;
    if (label.contains('Stomach'))   return Icons.water_drop_outlined;
    if (label.contains('Water'))     return Icons.local_drink_outlined;
    return Icons.schedule_outlined;
  }

  Future<void> _pickTime(int slotIndex) async {
    final slot = _currentDay.slots[slotIndex];
    final picked = await showTimePicker(
      context: context,
      initialTime: slot.time,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => slot.time = picked);
    }
  }

  Future<void> _pickReminder(int slotIndex) async {
    final options = [15, 30, 45, 60];
    final slot = _currentDay.slots[slotIndex];
    final picked = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reminder After', style: m(15, FontWeight.w700, textDark)),
            const SizedBox(height: 12),
            ...options.map((mins) => ListTile(
              title: Text('$mins mins', style: m(14, FontWeight.w500, textDark)),
              trailing: slot.reminderAfterMins == mins
                  ? const Icon(Icons.check, color: primary)
                  : null,
              onTap: () => Navigator.pop(ctx, mins),
            )),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => slot.reminderAfterMins = picked);
    }
  }

  Future<void> _editLabel(int slotIndex) async {
    final slot = _currentDay.slots[slotIndex];
    String selectedLabel = _labelOptions.contains(slot.label)
        ? slot.label
        : _labelOptions[0];

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: textGrey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Select Timing', style: m(15, FontWeight.w700, textDark)),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          ..._labelOptions.map((option) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              _getIconForLabel(option),
                              color: selectedLabel == option ? primary : textGrey,
                              size: 20,
                            ),
                            title: Text(option, style: m(14, FontWeight.w500, textDark)),
                            trailing: selectedLabel == option
                                ? const Icon(Icons.check_circle, color: primary, size: 20)
                                : const Icon(Icons.radio_button_unchecked, color: textGrey, size: 20),
                            onTap: () {
                              setModalState(() => selectedLabel = option);
                              Future.delayed(
                                const Duration(milliseconds: 150),
                                    () => Navigator.pop(ctx, option),
                              );
                            },
                          )),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => slot.label = result);
    }
  }

  void _toggleStatus(int slotIndex) {
    setState(() {
      final slot = _currentDay.slots[slotIndex];
      slot.status = slot.status == SlotTakenStatus.taken
          ? SlotTakenStatus.scheduled
          : SlotTakenStatus.taken;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Medication Adherence', style: m(16, FontWeight.w700, textDark)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildDaySelector(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _currentDay.slots.length,
              itemBuilder: (ctx, i) => _buildSlotCard(i),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSlot,
        backgroundColor: primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Slot', style: m(13, FontWeight.w700, Colors.white)),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_days.length, (i) {
          final isSelected = i == _selectedDayIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _days[i],
                style: m(11, FontWeight.w700, isSelected ? Colors.white : textGrey),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSlotCard(int index) {
    final slot = _currentDay.slots[index];
    final isTaken = slot.status == SlotTakenStatus.taken;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Slot header
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Slot ${index + 1}', style: m(14, FontWeight.w700, textDark)),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: dangerRed, size: 20),
                onPressed: () => _deleteSlot(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),

            const Divider(height: 16, color: cardBorder),

            // Label row
            _infoRow('Label:', slot.label, () => _editLabel(index)),
            const SizedBox(height: 10),

            // Time row
            _infoRow('Time:', _formatTime(slot.time), () => _pickTime(index)),
            const SizedBox(height: 10),

            // Reminder row
            _infoRow('Reminder after:', '${slot.reminderAfterMins} mins', () => _pickReminder(index)),

            const SizedBox(height: 14),

            // Status badge
            GestureDetector(
              onTap: () => _toggleStatus(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isTaken ? lightGreen : lightRed,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    isTaken ? Icons.check_circle : Icons.cancel_outlined,
                    color: isTaken ? okGreen : dangerRed,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isTaken ? 'Taken' : 'Not Taken',
                    style: m(12, FontWeight.w700, isTaken ? okGreen : dangerRed),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, VoidCallback onEdit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: m(13, FontWeight.w500, textGrey)),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: primaryBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value, style: m(12, FontWeight.w600, primary)),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onEdit,
            child: const Icon(Icons.edit, color: textGrey, size: 16),
          ),
        ]),
      ],
    );
  }

  void _addSlot() {
    setState(() {
      _currentDay.slots.add(PillSlot(
        label: 'After Lunch',
        time: const TimeOfDay(hour: 12, minute: 0),
        reminderAfterMins: 30,
        status: SlotTakenStatus.scheduled,
      ));
    });
  }

  void _deleteSlot(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete Slot', style: m(15, FontWeight.w700, textDark)),
        content: Text(
          'Are you sure you want to delete Slot ${index + 1}?',
          style: m(13, FontWeight.w500, textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: m(13, FontWeight.w600, textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _currentDay.slots.removeAt(index));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete', style: m(13, FontWeight.w700, Colors.white)),
          ),
        ],
      ),
    );
  }
}