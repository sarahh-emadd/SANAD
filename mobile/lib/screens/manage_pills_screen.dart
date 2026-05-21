import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

// ── Palette ────────────────────────────────────────────────────────────────
const _primary    = Color(0xFF2FA884);
const _primaryBg  = Color(0xFFE6F4F0);
const _okGreen    = Color(0xFF388E3C);
const _lightGreen = Color(0xFFEEF7EE);
const _dangerRed  = Color(0xFFE53935);
const _lightRed   = Color(0xFFFFF0EE);
const _amber      = Color(0xFFF59E0B);
const _lightAmber = Color(0xFFFFF8E1);
const _bgColor    = Color(0xFFF5F7F6);
const _textDark   = Color(0xFF1A1A1A);
const _textGrey   = Color(0xFFAAAAAA);
const _cardBorder = Color(0xFFEEEEEE);

TextStyle _m(double size, FontWeight weight, Color color) =>
    TextStyle(fontFamily: 'Montserrat', fontSize: size, fontWeight: weight, color: color);

const List<String> _labelOptions = [
  'Before Breakfast', 'After Breakfast',
  'Before Lunch',     'After Lunch',
  'Before Dinner',    'After Dinner',
  'Before Sleep',     'Empty Stomach',
  'With Water',
];

IconData _iconForLabel(String label) {
  if (label.contains('Breakfast')) return Icons.wb_sunny_outlined;
  if (label.contains('Lunch'))     return Icons.light_mode_outlined;
  if (label.contains('Dinner'))    return Icons.nights_stay_outlined;
  if (label.contains('Sleep'))     return Icons.bedtime_outlined;
  if (label.contains('Stomach'))   return Icons.water_drop_outlined;
  if (label.contains('Water'))     return Icons.local_drink_outlined;
  return Icons.schedule_outlined;
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class ManagePillsScreen extends StatefulWidget {
  final String elderlyId;
  const ManagePillsScreen({super.key, required this.elderlyId});

  @override
  State<ManagePillsScreen> createState() => _ManagePillsScreenState();
}

class _ManagePillsScreenState extends State<ManagePillsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Slots data from API
  List<Map<String, dynamic>> _slots = [];
  bool _loadingSlots = true;
  String? _error;

  // Today's dose log
  List<Map<String, dynamic>> _todayLogs = [];
  bool _loadingLogs = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── API helpers ─────────────────────────────────────────────────────────────

  Future<String?> _token() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadSlots(), _loadToday()]);
  }

  Future<void> _loadSlots() async {
    setState(() { _loadingSlots = true; _error = null; });
    final token = await _token();
    if (token == null) {
      setState(() { _loadingSlots = false; _error = 'Not authenticated'; });
      return;
    }

    try {
      final res = await http.get(
        Uri.parse(ApiConfig.pillboxSlots(widget.elderlyId)),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _slots = List<Map<String, dynamic>>.from(data['data']['slots']);
          _loadingSlots = false;
        });
      } else {
        setState(() { _loadingSlots = false; _error = 'Failed to load slots'; });
      }
    } catch (e) {
      setState(() { _loadingSlots = false; _error = 'Connection error'; });
    }
  }

  Future<void> _loadToday() async {
    setState(() => _loadingLogs = true);
    final token = await _token();
    if (token == null) { setState(() => _loadingLogs = false); return; }

    try {
      final res = await http.get(
        Uri.parse(ApiConfig.pillboxToday(widget.elderlyId)),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _todayLogs = List<Map<String, dynamic>>.from(data['data']['schedule']);
          _loadingLogs = false;
        });
      } else {
        setState(() => _loadingLogs = false);
      }
    } catch (_) {
      setState(() => _loadingLogs = false);
    }
  }

  Future<void> _saveSlot(int slotIndex, {
    required String medicationName,
    required String? notes,
    required bool isActive,
  }) async {
    final token = await _token();
    if (token == null) return;
    final slotNumber = slotIndex + 1;

    await http.put(
      Uri.parse(ApiConfig.pillboxSlot(widget.elderlyId, slotNumber)),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'medication_name': medicationName,
        'notes': notes,
        'is_active': isActive,
      }),
    ).timeout(ApiConfig.timeout);

    await _loadSlots();
  }

  Future<void> _addSchedule(String slotId, String time, String label) async {
    final token = await _token();
    if (token == null) return;

    await http.post(
      Uri.parse(ApiConfig.pillboxSchedules),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'slot_id':    slotId,
        'elderly_id': widget.elderlyId,
        'time':       time,
        'label':      label,
      }),
    ).timeout(ApiConfig.timeout);

    await _loadAll();
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    final token = await _token();
    if (token == null) return;

    await http.delete(
      Uri.parse(ApiConfig.pillboxScheduleById(scheduleId)),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(ApiConfig.timeout);

    await _loadAll();
  }

  // ── UI helpers ───────────────────────────────────────────────────────────────

  String _formatTime(String hhmm) {
    final parts = hhmm.split(':');
    final h     = int.parse(parts[0]);
    final m     = parts[1];
    final ampm  = h >= 12 ? 'PM' : 'AM';
    final h12   = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $ampm';
  }

  Future<void> _showEditSlotDialog(int slotIndex) async {
    final slot    = _slots[slotIndex];
    final medCtrl = TextEditingController(text: slot['medication_name'] ?? '');
    final noteCtrl= TextEditingController(text: slot['notes'] ?? '');
    bool isActive = slot['is_active'] as bool? ?? false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Slot ${slotIndex + 1} — Medication',
              style: _m(15, FontWeight.w700, _textDark)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: medCtrl,
                decoration: InputDecoration(
                  labelText: 'Medication Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: Text('Slot Active', style: _m(13, FontWeight.w600, _textDark)),
                value: isActive,
                activeThumbColor: _primary,
                onChanged: (v) => setS(() => isActive = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: _m(13, FontWeight.w600, _textGrey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _saveSlot(
                  slotIndex,
                  medicationName: medCtrl.text.trim(),
                  notes: noteCtrl.text.trim().isEmpty
                      ? null : noteCtrl.text.trim(),
                  isActive: isActive,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Save', style: _m(13, FontWeight.w700, Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddScheduleDialog(String slotId) async {
    TimeOfDay time  = const TimeOfDay(hour: 8, minute: 0);
    String    label = _labelOptions[0];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          String hhmm() {
            final h = time.hour.toString().padLeft(2, '0');
            final m = time.minute.toString().padLeft(2, '0');
            return '$h:$m';
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: _textGrey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Add Schedule', style: _m(16, FontWeight.w700, _textDark)),
                const SizedBox(height: 20),

                // Time picker row
                GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: time,
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: _primary, onPrimary: Colors.white,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setS(() => time = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _primaryBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      const Icon(Icons.access_time,
                          color: _primary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        '${time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod}'
                        ':${time.minute.toString().padLeft(2, '0')} '
                        '${time.period == DayPeriod.am ? 'AM' : 'PM'}',
                        style: _m(14, FontWeight.w600, _primary),
                      ),
                      const Spacer(),
                      const Icon(Icons.edit, color: _primary, size: 16),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Label chips
                Text('Label', style: _m(13, FontWeight.w600, _textGrey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _labelOptions.map((opt) {
                    final sel = opt == label;
                    return GestureDetector(
                      onTap: () => setS(() => label = opt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel ? _primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sel ? _primary : _cardBorder),
                        ),
                        child: Text(
                          opt,
                          style: _m(11, FontWeight.w600,
                              sel ? Colors.white : _textGrey),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _addSchedule(slotId, hhmm(), label);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Add Schedule',
                        style: _m(14, FontWeight.w700, Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: _textDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Smart Pillbox', style: _m(16, FontWeight.w700, _textDark)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _primary),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: _primary,
          unselectedLabelColor: _textGrey,
          indicatorColor: _primary,
          labelStyle: _m(13, FontWeight.w700, _primary),
          tabs: const [
            Tab(text: 'Slots & Schedule'),
            Tab(text: "Today's Doses"),
          ],
        ),
      ),
      body: _loadingSlots
          ? const Center(
              child: CircularProgressIndicator(color: _primary))
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tab,
                  children: [
                    _buildSlotsTab(),
                    _buildTodayTab(),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: _dangerRed, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: _m(14, FontWeight.w600, _textGrey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary, foregroundColor: Colors.white),
            child: Text('Retry', style: _m(13, FontWeight.w700, Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Slots Tab ───────────────────────────────────────────────────────────────

  Widget _buildSlotsTab() {
    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadSlots,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _slots.length,
        itemBuilder: (_, i) => _buildSlotCard(i),
      ),
    );
  }

  Widget _buildSlotCard(int i) {
    final slot      = _slots[i];
    final schedules =
        List<Map<String, dynamic>>.from(slot['schedules'] ?? []);
    final medName   =
        (slot['medication_name'] as String?)?.isNotEmpty == true
            ? slot['medication_name'] as String
            : 'Not set';
    final isActive  = slot['is_active'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isActive ? _primary : _textGrey,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('${i + 1}',
                    style: _m(16, FontWeight.w800, Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Slot ${i + 1}',
                    style: _m(14, FontWeight.w700, Colors.white)),
              ),
              GestureDetector(
                onTap: () => _showEditSlotDialog(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.edit, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text('Edit',
                        style: _m(11, FontWeight.w600, Colors.white)),
                  ]),
                ),
              ),
            ]),
          ),

          // Medication info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              const Icon(Icons.medication_outlined,
                  color: _primary, size: 18),
              const SizedBox(width: 8),
              Text(medName, style: _m(13, FontWeight.w600, _textDark)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive ? _lightGreen : _lightRed,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: _m(10, FontWeight.w700,
                      isActive ? _okGreen : _dangerRed),
                ),
              ),
            ]),
          ),

          if ((slot['notes'] as String?)?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(slot['notes'] as String,
                  style: _m(11, FontWeight.w400, _textGrey)),
            ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Divider(height: 1, color: _cardBorder),
          ),

          // Schedules
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text('Schedules',
                  style: _m(12, FontWeight.w700, _textGrey)),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    _showAddScheduleDialog(slot['id'] as String),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_circle_outline,
                      color: _primary, size: 16),
                  const SizedBox(width: 4),
                  Text('Add', style: _m(12, FontWeight.w600, _primary)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 8),

          if (schedules.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'No schedules yet. Tap Add to set a time.',
                style: _m(12, FontWeight.w400, _textGrey),
              ),
            )
          else
            ...schedules
                .map((sc) => _buildScheduleRow(slot['id'] as String, sc)),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(String slotId, Map<String, dynamic> sc) {
    final time  = _formatTime(sc['scheduled_time'] as String);
    final label = sc['label'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _primaryBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(time, style: _m(12, FontWeight.w700, _primary)),
        ),
        const SizedBox(width: 10),
        Icon(_iconForLabel(label), color: _textGrey, size: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(label, style: _m(12, FontWeight.w500, _textGrey)),
        ),
        GestureDetector(
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Remove Schedule',
                    style: _m(14, FontWeight.w700, _textDark)),
                content: Text('Remove $time ($label)?',
                    style: _m(13, FontWeight.w400, _textGrey)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel',
                        style: _m(13, FontWeight.w600, _textGrey)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Remove',
                        style: _m(13, FontWeight.w700, _dangerRed)),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await _deleteSchedule(sc['id'] as String);
            }
          },
          child: const Icon(Icons.close, color: _dangerRed, size: 18),
        ),
      ]),
    );
  }

  // ── Today's Doses Tab ───────────────────────────────────────────────────────

  Widget _buildTodayTab() {
    if (_loadingLogs) {
      return const Center(
          child: CircularProgressIndicator(color: _primary));
    }

    if (_todayLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medication_outlined,
                color: _textGrey, size: 56),
            const SizedBox(height: 12),
            Text('No doses scheduled for today',
                style: _m(14, FontWeight.w600, _textGrey)),
            const SizedBox(height: 6),
            Text('Set up slots and schedules in the first tab',
                style: _m(12, FontWeight.w400, _textGrey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadToday,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _todayLogs.length,
        itemBuilder: (_, i) => _buildLogRow(_todayLogs[i]),
      ),
    );
  }

  Widget _buildLogRow(Map<String, dynamic> entry) {
    final slotNum = entry['slot_number'] ?? '?';
    final medName =
        (entry['medication_name'] as String?)?.isNotEmpty == true
            ? entry['medication_name'] as String
            : 'Slot $slotNum';
    final time  = _formatTime(
        entry['scheduled_time'] as String? ?? '00:00');
    final label = entry['label'] as String? ?? '';
    final status = entry['dose_status'] as String? ?? 'pending';

    Color    statusColor;
    Color    statusBg;
    IconData statusIcon;
    String   statusLabel;

    switch (status) {
      case 'taken':
        statusColor  = _okGreen;
        statusBg     = _lightGreen;
        statusIcon   = Icons.check_circle;
        statusLabel  = 'Taken';
        break;
      case 'missed':
        statusColor  = _dangerRed;
        statusBg     = _lightRed;
        statusIcon   = Icons.cancel;
        statusLabel  = 'Missed';
        break;
      default:
        statusColor  = _amber;
        statusBg     = _lightAmber;
        statusIcon   = Icons.schedule;
        statusLabel  = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _primaryBg,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text('$slotNum',
              style: _m(18, FontWeight.w800, _primary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(medName,
                  style: _m(13, FontWeight.w700, _textDark)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.access_time,
                    size: 12, color: _textGrey),
                const SizedBox(width: 4),
                Text(time, style: _m(12, FontWeight.w500, _textGrey)),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text('· $label',
                      style: _m(11, FontWeight.w400, _textGrey)),
                ],
              ]),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(statusIcon, color: statusColor, size: 14),
            const SizedBox(width: 4),
            Text(statusLabel,
                style: _m(11, FontWeight.w700, statusColor)),
          ]),
        ),
      ]),
    );
  }
}
