import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import 'elder_profile_step2_screen.dart';

class ElderProfileStep1Screen extends StatefulWidget {
  const ElderProfileStep1Screen({super.key});

  @override
  State<ElderProfileStep1Screen> createState() =>
      _ElderProfileStep1ScreenState();
}

class _ElderProfileStep1ScreenState extends State<ElderProfileStep1Screen> {
  final _formKey = GlobalKey<FormState>();

  // Basic Info
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _selectedBloodType;
  String? _selectedGender;

  // Safety Info
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyEmailController = TextEditingController();
  String? _emergencyRelationship;

  final List<String> _bloodTypes = [
    'A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−',
  ];

  final List<String> _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];

  final List<String> _relationships = [
    'Son', 'Daughter', 'Spouse', 'Parent', 'Sibling',
    'Professional Caregiver', 'Friend', 'Other',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyEmailController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 65),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primaryGreen,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  void _goNext() {
    if (_formKey.currentState!.validate()) {
      final elderData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'dateOfBirth': _dateOfBirth,
        'bloodType': _selectedBloodType,
        'gender': _selectedGender,
        'emergencyName': _emergencyNameController.text.trim(),
        'emergencyPhone': _emergencyPhoneController.text.trim(),
        'emergencyEmail': _emergencyEmailController.text.trim(),
        'emergencyRelationship': _emergencyRelationship,
      };
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ElderProfileStep2Screen(elderData: elderData),
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
          // Progress indicator
          _buildProgressBar(currentStep: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // ── Photo Upload ──
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {},
                            child: Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_outline,
                                  size: 40, color: AppTheme.primaryGreen),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload Photo (Optional)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Section: Basic Information ──
                    _sectionHeader('Basic Information', Icons.person_outline),
                    const SizedBox(height: 14),

                    // First & Last Name
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            style: GoogleFonts.inter(
                                fontSize: 14, color: AppTheme.textDark),
                            validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                            decoration: const InputDecoration(
                              hintText: 'First Name ',
                              prefixIcon: Icon(Icons.elderly_outlined,
                                  color: AppTheme.hintGrey, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            style: GoogleFonts.inter(
                                fontSize: 14, color: AppTheme.textDark),
                            validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                            decoration: const InputDecoration(
                              hintText: 'Last Name ',
                              prefixIcon: Icon(Icons.elderly_outlined,
                                  color: AppTheme.hintGrey, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Date of Birth
                    GestureDetector(
                      onTap: _pickDate,
                      child: AbsorbPointer(
                        child: TextFormField(
                          readOnly: true,
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppTheme.textDark),
                          validator: (_) =>
                          _dateOfBirth == null ? 'Please select date of birth' : null,
                          decoration: InputDecoration(
                            hintText: _dateOfBirth == null
                                ? 'Date of Birth '
                                : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 14,
                              color: _dateOfBirth == null
                                  ? AppTheme.hintGrey
                                  : AppTheme.textDark,
                            ),
                            prefixIcon: const Icon(Icons.calendar_month_outlined,
                                color: AppTheme.hintGrey, size: 20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Blood Type
                    _buildDropdown(
                      value: _selectedBloodType,
                      hint: 'Blood Type ',
                      icon: Icons.bloodtype_outlined,
                      items: _bloodTypes,
                      onChanged: (v) => setState(() => _selectedBloodType = v),
                      validator: (v) =>
                      (v == null) ? 'Please select blood type' : null,
                    ),
                    const SizedBox(height: 14),

                    // Gender
                    _buildDropdown(
                      value: _selectedGender,
                      hint: 'Gender ',
                      icon: Icons.wc_outlined,
                      items: _genders,
                      onChanged: (v) => setState(() => _selectedGender = v),
                      validator: (v) =>
                      (v == null) ? 'Please select gender' : null,
                    ),
                    const SizedBox(height: 28),

                    // ── Section: Safety Information ──
                    _sectionHeader(
                        'Safety Information', Icons.health_and_safety_outlined),
                    const SizedBox(height: 14),

                    // Emergency Contact Name
                    CustomTextField(
                      hintText: 'Emergency Contact Name ',
                      prefixIcon: Icons.person_pin_outlined,
                      controller: _emergencyNameController,
                      validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Please enter emergency contact name'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Emergency Contact Phone
                    CustomTextField(
                      hintText: 'Emergency Contact Number ',
                      prefixIcon: Icons.phone_outlined,
                      controller: _emergencyPhoneController,
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Please enter emergency contact number'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Emergency Relationship
                    _buildDropdown(
                      value: _emergencyRelationship,
                      hint: 'Emergency Contact Relationship ',
                      icon: Icons.people_outline,
                      items: _relationships,
                      onChanged: (v) =>
                          setState(() => _emergencyRelationship = v),
                      validator: (v) =>
                      (v == null) ? 'Please select relationship' : null,
                    ),
                    const SizedBox(height: 14),

                    // Emergency Contact Email
                    CustomTextField(
                      hintText: 'Emergency Contact Email ',
                      prefixIcon: Icons.mail_outline,
                      controller: _emergencyEmailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter emergency contact email';
                        }
                        if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(v.trim())) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

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

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
    required String? Function(String?) validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.errorRed, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.errorRed, width: 1.8),
        ),
        prefixIcon:
        Icon(icon, color: AppTheme.hintGrey, size: 20),
      ),
      hint: Text(hint,
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.hintGrey)),
      icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.hintGrey),
      dropdownColor: Colors.white,
      items: items
          .map((item) => DropdownMenuItem(
        value: item,
        child: Text(item,
            style: GoogleFonts.inter(
                fontSize: 14, color: AppTheme.textDark)),
      ))
          .toList(),
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