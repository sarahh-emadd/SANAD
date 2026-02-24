import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'elder_connect_qr_screen.dart';

class ElderProfileStep4Screen extends StatefulWidget {
  final Map<String, dynamic> elderData;

  const ElderProfileStep4Screen({super.key, required this.elderData});

  @override
  State<ElderProfileStep4Screen> createState() =>
      _ElderProfileStep4ScreenState();
}

class _ElderProfileStep4ScreenState extends State<ElderProfileStep4Screen> {
  final _formKey = GlobalKey<FormState>();

  String? _mobilityLevel;
  TimeOfDay? _sleepTime;
  TimeOfDay? _wakeTime;

  final List<Map<String, dynamic>> _mobilityOptions = [
    {
      'value': 'independent',
      'label': 'Independent',
      'icon': Icons.directions_walk,
      'desc': 'Moves around freely without assistance',
    },
    {
      'value': 'needs_assistance',
      'label': 'Needs Assistance',
      'icon': Icons.support,
      'desc': 'Requires help with some movements',
    },
    {
      'value': 'bedridden',
      'label': 'Bedridden',
      'icon': Icons.bed,
      'desc': 'Confined to bed most of the time',
    },
    {
      'value': 'wheelchair',
      'label': 'Wheelchair',
      'icon': Icons.accessible,
      'desc': 'Uses a wheelchair for mobility',
    },
  ];

  Future<void> _pickTime({required bool isSleep}) async {
    final initial = isSleep
        ? (_sleepTime ?? const TimeOfDay(hour: 22, minute: 0))
        : (_wakeTime ?? const TimeOfDay(hour: 7, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primaryGreen,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isSleep) {
          _sleepTime = picked;
        } else {
          _wakeTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _createProfile() {
    if (_mobilityLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a mobility level',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final updatedData = {
      ...widget.elderData,
      'mobilityLevel': _mobilityLevel,
      'sleepTime': _sleepTime != null ? _formatTime(_sleepTime) : null,
      'wakeTime': _wakeTime != null ? _formatTime(_wakeTime) : null,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ElderConnectQRScreen(elderData: updatedData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: AppTheme.textDark),
          ),
        ),
        title: Text(
          'Set up New Elder Profile',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryGreen,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildProgressBar(currentStep: 4),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // ── Physical Characteristics ──
                    _sectionHeader(
                        'Physical Characteristics', Icons.accessibility_new_outlined),
                    const SizedBox(height: 6),
                    Text(
                      'Select the mobility level that best describes the elder.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppTheme.textLight,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Mobility Level *',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mobility Cards
                    ...(_mobilityOptions.map((option) {
                      final isSelected = _mobilityLevel == option['value'];
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _mobilityLevel = option['value']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryGreen.withAlpha(20)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : AppTheme.borderColor,
                              width: isSelected ? 1.8 : 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primaryGreen
                                      : AppTheme.primaryGreen.withAlpha(30),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  option['icon'] as IconData,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.primaryGreen,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option['label'] as String,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? AppTheme.primaryGreen
                                            : AppTheme.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      option['desc'] as String,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppTheme.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle,
                                    color: AppTheme.primaryGreen, size: 20),
                            ],
                          ),
                        ),
                      );
                    }).toList()),

                    const SizedBox(height: 28),

                    // ── Activity Level & Daily Routine ──
                    _sectionHeader(
                        'Activity Level & Daily Routine', Icons.schedule_outlined),
                    const SizedBox(height: 6),
                    Text(
                      'Help caregivers and reminders align with the elder\'s natural rhythm.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppTheme.textLight,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sleep & Wake Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePicker(
                            label: 'Typical Sleep Time',
                            icon: Icons.bedtime_outlined,
                            time: _sleepTime,
                            onTap: () => _pickTime(isSleep: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTimePicker(
                            label: 'Typical Wake Time',
                            icon: Icons.wb_sunny_outlined,
                            time: _wakeTime,
                            onTap: () => _pickTime(isSleep: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),

                    // ── Create Profile Button ──
                    ElevatedButton(
                      onPressed: _createProfile,
                      child: const Text('Create Profile'),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required IconData icon,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: time != null ? AppTheme.primaryGreen : AppTheme.borderColor,
            width: time != null ? 1.8 : 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 16,
                    color: time != null
                        ? AppTheme.primaryGreen
                        : AppTheme.hintGrey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              time != null ? _formatTime(time) : 'Tap to set',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color:
                time != null ? AppTheme.primaryGreen : AppTheme.hintGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}

Widget _buildProgressBar({required int currentStep}) {
  const totalSteps = 4;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(totalSteps, (index) {
            final stepNum = index + 1;
            final isActive = stepNum <= currentStep;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index < totalSteps - 1 ? 6 : 0),
                height: 5,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.primaryGreen
                      : AppTheme.primaryGreen.withAlpha(50),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          'Step $currentStep of $totalSteps',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textLight,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}