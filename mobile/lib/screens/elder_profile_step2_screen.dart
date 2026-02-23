import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'elder_profile_step3_screen.dart';

class ElderProfileStep2Screen extends StatefulWidget {
  final Map<String, dynamic> elderData;

  const ElderProfileStep2Screen({super.key, required this.elderData});

  @override
  State<ElderProfileStep2Screen> createState() =>
      _ElderProfileStep2ScreenState();
}

class _ElderProfileStep2ScreenState extends State<ElderProfileStep2Screen> {
  final _formKey = GlobalKey<FormState>();

  final _phoneNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();

  String? _selectedCountry;
  String? _selectedCity;

  // Country data: name → { code, flag, dial, cities }
  static const Map<String, Map<String, dynamic>> _countryData = {
    'Egypt': {
      'dial': '+20',
      'flag': '🇪🇬',
      'cities': [
        'Cairo', 'Alexandria', 'Giza', 'Shubra El Kheima', 'Port Said',
        'Suez', 'Luxor', 'Mansoura', 'Tanta', 'Asyut', 'Ismailia',
        'Fayyum', 'Zagazig', 'Damietta', 'Aswan', 'Minya', 'Hurghada',
        'Sharm El Sheikh', 'Sohag', 'Beni Suef',
      ],
    },
    'Saudi Arabia': {
      'dial': '+966',
      'flag': '🇸🇦',
      'cities': [
        'Riyadh', 'Jeddah', 'Mecca', 'Medina', 'Dammam', 'Khobar',
        'Tabuk', 'Abha', 'Taif', 'Buraidah', 'Najran', 'Hail',
        'Khamis Mushait', 'Jubail', 'Yanbu',
      ],
    },
    'United Arab Emirates': {
      'dial': '+971',
      'flag': '🇦🇪',
      'cities': [
        'Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman', 'Ras Al Khaimah',
        'Fujairah', 'Umm Al Quwain', 'Al Ain',
      ],
    },
    'Kuwait': {
      'dial': '+965',
      'flag': '🇰🇼',
      'cities': [
        'Kuwait City', 'Hawalli', 'Salmiya', 'Farwaniya', 'Ahmadi',
        'Jahra', 'Mangaf', 'Fahaheel',
      ],
    },
    'Jordan': {
      'dial': '+962',
      'flag': '🇯🇴',
      'cities': [
        'Amman', 'Zarqa', 'Irbid', 'Aqaba', 'Madaba', 'Karak',
        'Salt', 'Mafraq', 'Jerash', 'Ajloun',
      ],
    },
    'Qatar': {
      'dial': '+974',
      'flag': '🇶🇦',
      'cities': [
        'Doha', 'Al Rayyan', 'Al Wakrah', 'Al Khor', 'Mesaieed',
        'Madinat ash Shamal', 'Dukhan',
      ],
    },
    'Bahrain': {
      'dial': '+973',
      'flag': '🇧🇭',
      'cities': [
        'Manama', 'Muharraq', 'Riffa', 'Hamad Town', 'Isa Town',
        'Sitra', 'Budaiya', 'Jidhafs',
      ],
    },
    'Oman': {
      'dial': '+968',
      'flag': '🇴🇲',
      'cities': [
        'Muscat', 'Seeb', 'Salalah', 'Bawshar', 'Sohar', 'Nizwa',
        'Sur', 'Ibri', 'Rustaq', 'Khasab',
      ],
    },
    'Lebanon': {
      'dial': '+961',
      'flag': '🇱🇧',
      'cities': [
        'Beirut', 'Tripoli', 'Sidon', 'Tyre', 'Jounieh', 'Zahle',
        'Baalbek', 'Nabatieh',
      ],
    },
    'Morocco': {
      'dial': '+212',
      'flag': '🇲🇦',
      'cities': [
        'Casablanca', 'Rabat', 'Fes', 'Marrakech', 'Agadir', 'Tangier',
        'Meknes', 'Oujda', 'Kenitra', 'Tetouan',
      ],
    },
    'Tunisia': {
      'dial': '+216',
      'flag': '🇹🇳',
      'cities': [
        'Tunis', 'Sfax', 'Sousse', 'Kairouan', 'Bizerte', 'Gabes',
        'Ariana', 'Gafsa', 'Monastir', 'Beja',
      ],
    },
    'Libya': {
      'dial': '+218',
      'flag': '🇱🇾',
      'cities': [
        'Tripoli', 'Benghazi', 'Misrata', 'Tarhuna', 'Al Bayda',
        'Zawiya', 'Sabha', 'Derna',
      ],
    },
    'Sudan': {
      'dial': '+249',
      'flag': '🇸🇩',
      'cities': [
        'Khartoum', 'Omdurman', 'Port Sudan', 'Kassala', 'El Obeid',
        'Wad Madani', 'Atbara',
      ],
    },
    'Iraq': {
      'dial': '+964',
      'flag': '🇮🇶',
      'cities': [
        'Baghdad', 'Basra', 'Mosul', 'Erbil', 'Kirkuk', 'Najaf',
        'Karbala', 'Nasiriyah', 'Ramadi', 'Fallujah',
      ],
    },
    'Syria': {
      'dial': '+963',
      'flag': '🇸🇾',
      'cities': [
        'Damascus', 'Aleppo', 'Homs', 'Hama', 'Latakia', 'Deir ez-Zor',
        'Raqqa', 'Tartus', 'Daraa',
      ],
    },
    'Turkey': {
      'dial': '+90',
      'flag': '🇹🇷',
      'cities': [
        'Istanbul', 'Ankara', 'Izmir', 'Bursa', 'Adana', 'Gaziantep',
        'Konya', 'Antalya', 'Kayseri', 'Mersin', 'Trabzon',
      ],
    },
    'United States': {
      'dial': '+1',
      'flag': '🇺🇸',
      'cities': [
        'New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix',
        'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Jose',
        'Austin', 'Miami', 'Seattle', 'Denver', 'Boston',
        'Nashville', 'Las Vegas', 'Atlanta', 'Washington DC',
      ],
    },
    'United Kingdom': {
      'dial': '+44',
      'flag': '🇬🇧',
      'cities': [
        'London', 'Birmingham', 'Manchester', 'Glasgow', 'Liverpool',
        'Leeds', 'Sheffield', 'Edinburgh', 'Bristol', 'Cardiff',
        'Leicester', 'Nottingham', 'Newcastle', 'Belfast', 'Southampton',
      ],
    },
    'Germany': {
      'dial': '+49',
      'flag': '🇩🇪',
      'cities': [
        'Berlin', 'Hamburg', 'Munich', 'Cologne', 'Frankfurt', 'Stuttgart',
        'Düsseldorf', 'Dortmund', 'Essen', 'Leipzig', 'Bremen', 'Dresden',
      ],
    },
    'France': {
      'dial': '+33',
      'flag': '🇫🇷',
      'cities': [
        'Paris', 'Marseille', 'Lyon', 'Toulouse', 'Nice', 'Nantes',
        'Strasbourg', 'Montpellier', 'Bordeaux', 'Lille', 'Rennes',
      ],
    },
    'Canada': {
      'dial': '+1',
      'flag': '🇨🇦',
      'cities': [
        'Toronto', 'Montreal', 'Vancouver', 'Calgary', 'Edmonton',
        'Ottawa', 'Winnipeg', 'Quebec City', 'Hamilton', 'Halifax',
      ],
    },
    'Australia': {
      'dial': '+61',
      'flag': '🇦🇺',
      'cities': [
        'Sydney', 'Melbourne', 'Brisbane', 'Perth', 'Adelaide',
        'Gold Coast', 'Canberra', 'Newcastle', 'Hobart',
      ],
    },
    'India': {
      'dial': '+91',
      'flag': '🇮🇳',
      'cities': [
        'Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai',
        'Kolkata', 'Pune', 'Ahmedabad', 'Jaipur', 'Surat',
        'Lucknow', 'Kanpur', 'Nagpur', 'Indore', 'Bhopal',
      ],
    },
    'Pakistan': {
      'dial': '+92',
      'flag': '🇵🇰',
      'cities': [
        'Karachi', 'Lahore', 'Islamabad', 'Faisalabad', 'Rawalpindi',
        'Multan', 'Hyderabad', 'Gujranwala', 'Peshawar', 'Quetta',
      ],
    },
  };

  List<String> get _countries => _countryData.keys.toList()..sort();

  List<String> get _cities {
    if (_selectedCountry == null) return [];
    final data = _countryData[_selectedCountry];
    return List<String>.from(data?['cities'] ?? []);
  }

  String get _dialCode {
    if (_selectedCountry == null) return '+--';
    return _countryData[_selectedCountry]?['dial'] ?? '';
  }

  String get _flag {
    if (_selectedCountry == null) return '🌍';
    return _countryData[_selectedCountry]?['flag'] ?? '🌍';
  }

  @override
  void dispose() {
    _phoneNumberController.dispose();
    _addressController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_formKey.currentState!.validate()) {
      final fullPhone = '$_dialCode ${_phoneNumberController.text.trim()}';
      final updatedData = {
        ...widget.elderData,
        'phone': fullPhone,
        'address': _addressController.text.trim(),
        'city': _selectedCity ?? '',
        'country': _selectedCountry ?? '',
        'state': _stateController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
      };
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ElderProfileStep3Screen(elderData: updatedData),
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
          _buildProgressBar(currentStep: 2),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    _sectionHeader('Contact & Address', Icons.location_on_outlined),
                    const SizedBox(height: 20),

                    // ── Country Dropdown (first so phone code auto-fills) ──
                    _buildDropdown(
                      value: _selectedCountry,
                      hint: 'Country ',
                      icon: Icons.public_outlined,
                      items: _countries,
                      onChanged: (v) => setState(() {
                        _selectedCountry = v;
                        _selectedCity = null;
                        _phoneNumberController.clear();
                      }),
                      validator: (v) =>
                      v == null ? 'Please select a country' : null,
                    ),
                    const SizedBox(height: 14),

                    // ── Phone with auto country code ──
                    FormField<String>(
                      validator: (_) {
                        if (_phoneNumberController.text.trim().isEmpty) {
                          return 'Please enter phone number';
                        }
                        if (_phoneNumberController.text.trim().length < 6) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                      builder: (fieldState) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: fieldState.hasError
                                      ? AppTheme.errorRed
                                      : AppTheme.borderColor,
                                  width: fieldState.hasError ? 1.8 : 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // ── Country Code Badge ──
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 16),
                                    decoration: BoxDecoration(
                                      color: _selectedCountry != null
                                          ? AppTheme.primaryGreen.withAlpha(15)
                                          : AppTheme.lightBackground,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(11),
                                        bottomLeft: Radius.circular(11),
                                      ),
                                      border: Border(
                                        right: BorderSide(
                                          color: fieldState.hasError
                                              ? AppTheme.errorRed
                                              .withAlpha(100)
                                              : AppTheme.borderColor,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _flag,
                                          style:
                                          const TextStyle(fontSize: 18),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _dialCode,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: _selectedCountry != null
                                                ? AppTheme.primaryGreen
                                                : AppTheme.hintGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ── Phone Number Input ──
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneNumberController,
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      onChanged: (_) => fieldState.didChange(null),
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: AppTheme.textDark),
                                      decoration: InputDecoration(
                                        hintText: _selectedCountry == null
                                            ? 'Select country first'
                                            : 'Phone Number ',
                                        hintStyle: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: AppTheme.hintGrey,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 16),
                                      ),
                                      enabled: _selectedCountry != null,
                                    ),
                                  ),

                                  const Padding(
                                    padding: EdgeInsets.only(right: 12),
                                    child: Icon(Icons.phone_outlined,
                                        color: AppTheme.hintGrey, size: 20),
                                  ),
                                ],
                              ),
                            ),
                            if (fieldState.hasError)
                              Padding(
                                padding:
                                const EdgeInsets.only(left: 12, top: 6),
                                child: Text(
                                  fieldState.errorText!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.errorRed,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // ── Address ──
                    TextFormField(
                      controller: _addressController,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppTheme.textDark),
                      validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Please enter address'
                          : null,
                      decoration: const InputDecoration(
                        hintText: 'Address ',
                        prefixIcon: Icon(Icons.home_outlined,
                            color: AppTheme.hintGrey, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── City Dropdown ──
                    _buildDropdown(
                      value: _selectedCity,
                      hint: _selectedCountry == null
                          ? 'Select Country First'
                          : 'City ',
                      icon: Icons.location_city_outlined,
                      items: _cities,
                      onChanged: _selectedCountry == null
                          ? null
                          : (v) => setState(() => _selectedCity = v),
                      validator: (v) =>
                      v == null ? 'Please select a city' : null,
                    ),

                    if (_selectedCountry == null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 6),
                        child: Text(
                          'Please select a country to see available cities',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppTheme.hintGrey,
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // ── Optional Divider ──
                    Row(
                      children: [
                        const Expanded(
                            child: Divider(color: AppTheme.borderColor)),
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
                        const Expanded(
                            child: Divider(color: AppTheme.borderColor)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── State ──
                    TextFormField(
                      controller: _stateController,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppTheme.textDark),
                      decoration: const InputDecoration(
                        hintText: 'State / Province',
                        prefixIcon: Icon(Icons.map_outlined,
                            color: AppTheme.hintGrey, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Postal Code ──
                    TextFormField(
                      controller: _postalCodeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppTheme.textDark),
                      decoration: const InputDecoration(
                        hintText: 'Postal Code',
                        prefixIcon: Icon(Icons.markunread_mailbox_outlined,
                            color: AppTheme.hintGrey, size: 20),
                      ),
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

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required void Function(String?)? onChanged,
    required String? Function(String?) validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: InputDecoration(
        filled: true,
        fillColor: onChanged == null ? AppTheme.lightBackground : Colors.white,
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppTheme.borderColor.withAlpha(120), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: AppTheme.primaryGreen, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: AppTheme.errorRed, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: AppTheme.errorRed, width: 1.8),
        ),
        prefixIcon: Icon(icon, color: AppTheme.hintGrey, size: 20),
      ),
      hint: Text(hint,
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.hintGrey)),
      icon:
      const Icon(Icons.keyboard_arrow_down, color: AppTheme.hintGrey),
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