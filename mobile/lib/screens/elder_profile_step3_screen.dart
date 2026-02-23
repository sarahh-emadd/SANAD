import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'elder_profile_step4_screen.dart';

class ElderProfileStep3Screen extends StatefulWidget {
  final Map<String, dynamic> elderData;

  const ElderProfileStep3Screen({super.key, required this.elderData});

  @override
  State<ElderProfileStep3Screen> createState() =>
      _ElderProfileStep3ScreenState();
}

class _ElderProfileStep3ScreenState extends State<ElderProfileStep3Screen> {
  final _formKey = GlobalKey<FormState>();

  final _medicalConditionsController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _currentMedicationsController = TextEditingController();
  final _doctorNameController = TextEditingController();
  final _doctorPhoneController = TextEditingController();
  final _hospitalPreferenceController = TextEditingController();

  @override
  void dispose() {
    _medicalConditionsController.dispose();
    _allergiesController.dispose();
    _currentMedicationsController.dispose();
    _doctorNameController.dispose();
    _doctorPhoneController.dispose();
    _hospitalPreferenceController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_formKey.currentState!.validate()) {
      final updatedData = {
        ...widget.elderData,
        'medicalConditions': _medicalConditionsController.text.trim(),
        'allergies': _allergiesController.text.trim(),
        'currentMedications': _currentMedicationsController.text.trim(),
        'doctorName': _doctorNameController.text.trim(),
        'doctorPhone': _doctorPhoneController.text.trim(),
        'hospitalPreference': _hospitalPreferenceController.text.trim(),
      };
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ElderProfileStep4Screen(elderData: updatedData),
        ),
      );
    }
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
          _buildProgressBar(currentStep: 3),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    _sectionHeader(
                        'Medical Information', Icons.medical_information_outlined),
                    const SizedBox(height: 6),
                    Text(
                      'This information helps emergency responders provide the best care.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppTheme.textLight,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Medical Conditions
                    _buildTextArea(
                      controller: _medicalConditionsController,
                      label: 'Medical Conditions',
                      hint: 'e.g. Diabetes, Hypertension, Arthritis...',
                      icon: Icons.monitor_heart_outlined,
                      isRequired: true,
                      validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Please describe medical conditions'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Allergies
                    _buildTextArea(
                      controller: _allergiesController,
                      label: 'Allergies',
                      hint: 'e.g. Penicillin, Peanuts, Latex...',
                      icon: Icons.warning_amber_outlined,
                      isRequired: true,
                      validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Please list any allergies (or write None)'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Current Medications
                    _buildTextArea(
                      controller: _currentMedicationsController,
                      label: 'Current Medications',
                      hint: 'e.g. Metformin 500mg, Aspirin 100mg...',
                      icon: Icons.medication_outlined,
                      isRequired: true,
                      validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Please list current medications (or write None)'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // ── Optional Section ──
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppTheme.borderColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Optional',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: AppTheme.borderColor)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Doctor Name
                    _buildField(
                      controller: _doctorNameController,
                      hint: 'Doctor Name ',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 14),

                    // Doctor Phone
                    _buildField(
                      controller: _doctorPhoneController,
                      hint: 'Doctor Phone ',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),

                    // Hospital Preference
                    _buildField(
                      controller: _hospitalPreferenceController,
                      hint: 'Hospital Preference ',
                      icon: Icons.local_hospital_outlined,
                    ),
                    const SizedBox(height: 36),

                    // ── Next Button ──
                    ElevatedButton(
                      onPressed: _goNext,
                      child: const Text('Next'),
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

  Widget _buildTextArea({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isRequired,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryGreen),
            const SizedBox(width: 6),
            Text(
              isRequired ? '$label *' : label,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: 3,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
                fontSize: 13, color: AppTheme.hintGrey, height: 1.5),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: AppTheme.borderColor, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: AppTheme.borderColor, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: AppTheme.primaryGreen, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.errorRed, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.errorRed, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textDark),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: AppTheme.borderColor, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: AppTheme.borderColor, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: AppTheme.primaryGreen, width: 1.8),
        ),
        prefixIcon: Icon(icon, color: AppTheme.hintGrey, size: 20),
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