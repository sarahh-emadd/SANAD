import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../config/app_settings_provider.dart';
import '../config/locale_provider.dart';
import '../l10n/app_strings.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../models/elderly_model.dart';
import '../services/auth_service.dart';
import '../services/elderly_service.dart';
import '../services/api_service.dart';
import 'role_selection_page.dart';
import 'caregiver_reconnect_screen.dart';

class CaregiverSettingsScreen extends StatefulWidget {
  const CaregiverSettingsScreen({super.key});

  @override
  State<CaregiverSettingsScreen> createState() =>
      _CaregiverSettingsScreenState();
}

class _CaregiverSettingsScreenState extends State<CaregiverSettingsScreen> {
  static const primary = Color(0xFF2FA884);
  static const primaryBg = Color(0xFFE6F4F0);
  static const dangerRed = Color(0xFFE53935);
  static const okGreen = Color(0xFF388E3C);
  static const lightGreen = Color(0xFFEEF7EE);
  static const bgColor = Color(0xFFF5F7F6);
  static const textDark = Color(0xFF1A1A1A);
  static const textGrey = Color(0xFFAAAAAA);
  static const cardBg = Color(0xFFF7F7F7);

  static TextStyle m(double size, FontWeight weight, Color color) => TextStyle(
      fontFamily: 'Montserrat',
      fontSize: size,
      fontWeight: weight,
      color: color);

  UserModel?   _user;
  ElderlyModel? _elder;
  bool _profileLoading = true;

  bool _notifAll = true;
  bool _notifMessages = true;
  bool _notifReminder = true;
  bool _notifActivity = true;
  bool _notifCamera = true;
  bool _notifMedication = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user   = await AuthService.getMe();
      final elders = await ElderlyService.getAll();
      if (!mounted) return;
      setState(() {
        _user   = user;
        _elder  = elders.isNotEmpty ? elders.first : null;
        _profileLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryBg,
        elevation: 0,
        surfaceTintColor: primaryBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings', style: m(18, FontWeight.w700, textDark)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            color: primaryBg,
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildProfileCard(),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('Accessibility'),
              const SizedBox(height: 10),
              _whiteCard(
                  child: Column(children: [
                _settingsTile(
                  icon: Icons.volume_up_outlined,
                  title: S.of(context).volume,
                  subtitle: settings.volumeLabel,
                  onTap: _showVolumeSheet,
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.text_fields_rounded,
                  title: S.of(context).textSize,
                  subtitle: '${settings.textSize} (Current)',
                  onTap: _showTextSizeSheet,
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.language_rounded,
                  title: S.of(context).language,
                  subtitle: context.watch<LocaleProvider>().isArabic
                      ? 'العربية'
                      : 'English',
                  onTap: _showLanguageSheet,
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.notifications_outlined,
                  title: S.of(context).notifications,
                  subtitle: _notifAll ? 'All Enabled' : 'Some Disabled',
                  onTap: _showNotificationsSheet,
                ),
              ])),
              const SizedBox(height: 20),
              _sectionLabel('Connected Devices'),
              const SizedBox(height: 10),
              _deviceCard(
                icon: Icons.wifi_rounded,
                iconBg: primaryBg,
                iconColor: primary,
                name: 'Smart Pillbox',
                statusLabel: 'Connected & Synced',
                statusDot: primary,
                detail: 'Last sync: 2 min ago · Battery: 87%',
              ),
              const SizedBox(height: 10),
              _deviceCard(
                icon: Icons.camera_alt_outlined,
                iconBg: lightGreen,
                iconColor: okGreen,
                name: 'Health Camera',
                statusLabel: 'Active & Monitoring',
                statusDot: okGreen,
                detail: 'Last check: just now · Privacy: Bedroom only',
              ),
              const SizedBox(height: 10),
              // ── Reconnect elder device via QR ──────────────────────
              if (_elder != null)
                _whiteCard(
                  child: _settingsTile(
                    icon: Icons.qr_code_rounded,
                    title: 'Reconnect Elder Device',
                    subtitle: 'Generate a new QR code for ${_elder!.fullName}',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CaregiverReconnectScreen(
                          elderlyId: _elder!.id,
                          elderlyName: _elder!.fullName,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _sectionLabel('Privacy & Security'),
              const SizedBox(height: 10),
              _whiteCard(
                  child: Column(children: [
                _settingsTile(
                  icon: Icons.shield_outlined,
                  title: 'Privacy Settings',
                  subtitle: 'Manage Camera & Data',
                  onTap: _showPrivacySheet,
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.description_outlined,
                  title: 'Terms and Conditions',
                  subtitle: 'All you need to know about our App',
                  onTap: _showTermsSheet,
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.key_outlined,
                  title: 'Change Password',
                  subtitle: null,
                  onTap: _showChangePasswordSheet,
                  showChevron: false,
                ),
              ])),
              const SizedBox(height: 28),
              _outlineActionButton(
                label: 'Sign Out',
                icon: Icons.logout_rounded,
                color: dangerRed,
                onTap: _showSignOutDialog,
              ),
              const SizedBox(height: 12),
              _outlineActionButton(
                label: 'Delete Account',
                icon: Icons.delete_outline_rounded,
                color: dangerRed,
                onTap: _showDeleteAccountDialog,
              ),
              const SizedBox(height: 36),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildProfileCard() {
    final displayName  = _user?.firstName ?? (_profileLoading ? '...' : 'Caregiver');
    final elderLine    = _elder != null
        ? 'Connected to ${_elder!.fullName}'
        : (_profileLoading ? '...' : 'No elder connected');
    final avatarLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => EditPersonalInformationScreen(user: _user, elder: _elder)));
            _loadProfile();
          },
          child: Row(children: [
            CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFFFE0B2),
                child: Text(avatarLetter, style: m(20, FontWeight.w700, const Color(0xFFE65100)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(displayName, style: m(15, FontWeight.w700, textDark)),
              const SizedBox(height: 3),
              Text(elderLine, style: m(12, FontWeight.w500, textGrey)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: textGrey),
          ]),
        ),
      ),
    );
  }

  // ── Volume Sheet ───────────────────────────────────
  void _showVolumeSheet() {
    final settings = context.read<AppSettingsProvider>();
    double tempVolume = settings.volume;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
          builder: (ctx, setSS) => Container(
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24))),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _sheetHeader(Icons.volume_up_outlined, 'Volume'),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                      child: Column(children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Low',
                                  style: m(12, FontWeight.w500, textGrey)),
                              Text('Medium',
                                  style: m(12, FontWeight.w500, textGrey)),
                              Text('High',
                                  style: m(12, FontWeight.w500, textGrey)),
                            ]),
                        const SizedBox(height: 12),
                        SliderTheme(
                          data: SliderTheme.of(ctx).copyWith(
                            activeTrackColor: textDark,
                            inactiveTrackColor: const Color(0xFFE0E0E0),
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 14),
                            overlayColor: Colors.black.withValues(alpha: 0.08),
                            trackHeight: 10,
                          ),
                          child: Slider(
                              value: tempVolume,
                              min: 0,
                              max: 1,
                              divisions: 2,
                              onChanged: (v) => setSS(() => tempVolume = v)),
                        ),
                        const SizedBox(height: 20),
                        _saveButton(() {
                          context
                              .read<AppSettingsProvider>()
                              .setVolume(tempVolume);
                          Navigator.pop(context);
                        }, 'Save'),
                      ])),
                ]),
              )),
    );
  }

  // ── Text Size Sheet ────────────────────────────────
  void _showTextSizeSheet() {
    final options = ['Large Mode', 'Medium', 'Small'];
    final settings = context.read<AppSettingsProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
          builder: (ctx, setSS) => Container(
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24))),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _sheetHeader(Icons.text_fields_rounded, 'Text Size'),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      child: Column(
                        children: options.map((opt) {
                          final isCurrent = opt == settings.textSize;
                          return GestureDetector(
                            onTap: () {
                              context
                                  .read<AppSettingsProvider>()
                                  .setTextSize(opt);
                              Navigator.pop(context);
                            },
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 18),
                              decoration: BoxDecoration(
                                color: isCurrent ? primaryBg : cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: isCurrent
                                    ? Border.all(color: primary, width: 1.5)
                                    : null,
                              ),
                              child: Text(
                                isCurrent ? '$opt (current)' : opt,
                                style: m(
                                    14,
                                    isCurrent
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    isCurrent ? primary : textDark),
                              ),
                            ),
                          );
                        }).toList(),
                      )),
                ]),
              )),
    );
  }

  // ── Language Sheet ─────────────────────────────────
  void _showLanguageSheet() {
    final options = [
      {'code': 'en', 'label': 'English', 'native': 'English'},
      {'code': 'ar', 'label': 'Arabic',  'native': 'العربية'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _sheetHeader(Icons.language_rounded, 'Language'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              children: options.map((opt) {
                final isCurrent = context.read<LocaleProvider>().locale.languageCode == opt['code'];
                return GestureDetector(
                  onTap: () {
                    context.read<LocaleProvider>().setLocale(opt['code']!);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                    decoration: BoxDecoration(
                      color: isCurrent ? primaryBg : cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: isCurrent ? Border.all(color: primary, width: 1.5) : null,
                    ),
                    child: Row(children: [
                      Text(opt['native']!, style: m(14, isCurrent ? FontWeight.w700 : FontWeight.w600,
                          isCurrent ? primary : textDark)),
                      const Spacer(),
                      if (isCurrent)
                        Icon(Icons.check_circle_rounded, color: primary, size: 18),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Notifications Sheet ────────────────────────────
  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setSS) {
        void sync(VoidCallback fn) {
          setSS(fn);
          setState(fn);
        }

        void toggleAll(bool v) => sync(() {
              _notifAll = v;
              _notifMessages = v;
              _notifReminder = v;
              _notifActivity = v;
              _notifCamera = v;
              _notifMedication = v;
            });
        void recalc() => sync(() {
              _notifAll = _notifMessages &&
                  _notifReminder &&
                  _notifActivity &&
                  _notifCamera &&
                  _notifMedication;
            });
        return Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHeader(Icons.notifications_outlined, 'Notifications'),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(children: [
                  _notifRow('All Enabled', _notifAll, (v) => toggleAll(v)),
                  _notifRow('Messages', _notifMessages, (v) {
                    sync(() => _notifMessages = v);
                    recalc();
                  }),
                  _notifRow('Reminder', _notifReminder, (v) {
                    sync(() => _notifReminder = v);
                    recalc();
                  }),
                  _notifRow('No Activity Alert', _notifActivity, (v) {
                    sync(() => _notifActivity = v);
                    recalc();
                  }),
                  _notifRow('Camera Notification', _notifCamera, (v) {
                    sync(() => _notifCamera = v);
                    recalc();
                  }),
                  _notifRow('Missed Medication', _notifMedication, (v) {
                    sync(() => _notifMedication = v);
                    recalc();
                  }),
                ])),
          ]),
        );
      }),
    );
  }

  // ── Privacy Sheet ──────────────────────────────────
  void _showPrivacySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            _sheetHeader(Icons.shield_outlined, 'Privacy Settings'),
            Expanded(
                child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _privacySection('📍 Location Data', [
                      'SANAD collects the elder\'s GPS location to help caregivers ensure their safety.',
                      'Location is only accessed when the app is in use and shared exclusively with the connected caregiver.',
                      'Location data is used to detect if the elder has left a safe zone or needs assistance.',
                    ]),
                    const SizedBox(height: 20),
                    _privacySection('📷 Camera & Monitoring', [
                      'The health camera monitors the elder\'s environment to detect falls or unusual activity.',
                      'Camera footage is processed securely and is only accessible to the authorized caregiver.',
                      'No footage is shared with third parties or used for advertising purposes.',
                    ]),
                    const SizedBox(height: 20),
                    _privacySection('💊 Medication Data', [
                      'SANAD tracks medication schedules and adherence using data from the smart pillbox sensor.',
                      'This information is stored securely and used solely to help caregivers monitor the elder\'s health.',
                    ]),
                    const SizedBox(height: 20),
                    _privacySection('👤 Personal Information', [
                      'We collect basic personal details for both the caregiver and the elder to provide a personalized experience.',
                      'This includes name, contact information, and medical history relevant to care.',
                      'Your data is never sold or shared with advertisers.',
                    ]),
                    const SizedBox(height: 20),
                    _privacySection('🔒 Data Security', [
                      'All data is encrypted in transit and at rest.',
                      'Access to personal data is strictly limited to the connected caregiver and the elder.',
                      'You can request deletion of your data at any time by contacting us.',
                    ]),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE6F4F0),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        'SANAD is an academic graduation project. Data is collected solely for the purpose of providing care and monitoring services. We are committed to protecting your privacy.',
                        style: m(12, FontWeight.w500, const Color(0xFF2FA884)),
                      ),
                    ),
                  ]),
            )),
          ]),
        ),
      ),
    );
  }

  // ── Terms Sheet ────────────────────────────────────
  void _showTermsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            _sheetHeader(Icons.description_outlined, 'Terms and Conditions'),
            Expanded(
                child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _privacySection('1. Acceptance of Terms', [
                      'By using SANAD, you agree to these Terms and Conditions.',
                      'SANAD is an academic graduation project designed to assist in elder care monitoring.',
                    ]),
                    const SizedBox(height: 20),
                    _privacySection('2. Use of the Application', [
                      'SANAD is intended to be used by authorized caregivers and their connected elders only.',
                      'You agree not to misuse the application or use it for any unlawful purpose.',
                      'The caregiver is responsible for ensuring the elder\'s consent before enabling monitoring features.',
                    ]),
                    const SizedBox(height: 20),
                    _privacySection('3. Monitoring & Privacy', [
                      'Camera monitoring, location tracking, and medication monitoring are features designed purely for safety.',
                      'All monitoring data is only visible to the connected caregiver and must not be shared outside the care relationship.',
                    ]),
                    const SizedBox(height: 20),
                    _privacySection('4. Data Responsibility', [
                      'You are responsible for keeping your login credentials secure.',
                      'Any unauthorized access to another person\'s data is strictly prohibited.',
                      'SANAD stores data securely, but we recommend not sharing sensitive medical information beyond what is necessary.',
                    ]),
                    const SizedBox(height: 20),
                    _privacySection('5. Limitation of Liability', [
                      'SANAD is an academic project and does not replace professional medical advice or emergency services.',
                      'In case of a medical emergency, always contact the appropriate emergency services immediately.',
                      'The SANAD team is not liable for any harm resulting from reliance solely on the application.',
                    ]),
                    const SizedBox(height: 20),
                    _privacySection('6. Changes to Terms', [
                      'These terms may be updated as the project evolves.',
                      'Continued use of SANAD after any changes constitutes your acceptance of the updated terms.',
                    ]),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE6F4F0),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        'Last updated: May 2025 · SANAD Graduation Project Team',
                        style: m(12, FontWeight.w500, const Color(0xFF2FA884)),
                      ),
                    ),
                  ]),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _privacySection(String title, List<String> points) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: m(14, FontWeight.w700, textDark)),
          const SizedBox(height: 10),
          ...points.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: m(13, FontWeight.w500, primary)),
                      Expanded(
                          child: Text(p,
                              style: m(13, FontWeight.w500,
                                  const Color(0xFF444444)))),
                    ]),
              )),
        ],
      );

  // ── Change Password Sheet ──────────────────────────
  void _showChangePasswordSheet() {
    final c1 = TextEditingController(),
        c2 = TextEditingController(),
        c3 = TextEditingController();
    bool s1 = false, s2 = false, s3 = false, saving = false;
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
          builder: (ctx, setSS) => Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: Container(
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24))),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _sheetHeader(Icons.lock_outline_rounded, 'Change Password'),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                        child: Column(children: [
                          _pwField(c1, 'Current Password', s1,
                              () => setSS(() => s1 = !s1)),
                          const SizedBox(height: 12),
                          _pwField(c2, 'New Password', s2,
                              () => setSS(() => s2 = !s2)),
                          const SizedBox(height: 12),
                          _pwField(c3, 'Confirm New Password', s3,
                              () => setSS(() => s3 = !s3)),
                          if (errorMsg != null) ...[
                            const SizedBox(height: 10),
                            Text(errorMsg!, style: m(12, FontWeight.w500, dangerRed)),
                          ],
                          const SizedBox(height: 24),
                          _saveButton(() async {
                            final old = c1.text.trim();
                            final nw  = c2.text.trim();
                            final cnf = c3.text.trim();
                            if (old.isEmpty || nw.isEmpty || cnf.isEmpty) {
                              setSS(() => errorMsg = 'All fields are required');
                              return;
                            }
                            if (nw != cnf) {
                              setSS(() => errorMsg = 'New passwords do not match');
                              return;
                            }
                            if (nw.length < 6) {
                              setSS(() => errorMsg = 'Password must be at least 6 characters');
                              return;
                            }
                            setSS(() { saving = true; errorMsg = null; });
                            try {
                              final user  = FirebaseAuth.instance.currentUser!;
                              final cred  = EmailAuthProvider.credential(
                                  email: user.email!, password: old);
                              await user.reauthenticateWithCredential(cred);
                              await user.updatePassword(nw);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Password updated successfully')));
                              }
                            } on FirebaseAuthException catch (e) {
                              setSS(() {
                                saving = false;
                                errorMsg = e.code == 'wrong-password'
                                    ? 'Current password is incorrect'
                                    : e.message ?? 'Failed to change password';
                              });
                            } catch (e) {
                              setSS(() { saving = false; errorMsg = e.toString(); });
                            }
                          }, saving ? 'Saving...' : 'Save Changes'),
                        ])),
                  ]),
                ),
              )),
    );
  }

  Widget _pwField(TextEditingController c, String hint, bool show,
          VoidCallback toggle) =>
      TextField(
        controller: c,
        obscureText: !show,
        style: m(13, FontWeight.w500, textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: m(13, FontWeight.w500, textGrey),
          prefixIcon:
              const Icon(Icons.lock_outline_rounded, color: textGrey, size: 20),
          suffixIcon: IconButton(
              icon: Icon(
                  show
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: textGrey,
                  size: 20),
              onPressed: toggle),
          filled: true,
          fillColor: cardBg,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: primary, width: 1.5)),
        ),
      );

  // ── Sign Out Dialog ────────────────────────────────
  void _showSignOutDialog() => showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (_) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sign out', style: m(18, FontWeight.w700, textDark)),
                    const SizedBox(height: 10),
                    Text('Are you sure you want to sign out?',
                        style: m(13, FontWeight.w500, textGrey)),
                    const SizedBox(height: 24),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFFE0E0E0), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50))),
                        child: Text('Cancel',
                            style: m(14, FontWeight.w700, textDark)),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await AuthService.signOut();
                          if (!context.mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RoleSelectionPage()),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50))),
                        child: Text('Sign Out',
                            style: m(14, FontWeight.w700, Colors.white)),
                      )),
                    ]),
                  ])),
        ),
      );

  // ── Delete Account Dialog ──────────────────────────
  void _showDeleteAccountDialog() => showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (_) => _DeleteAccountDialog(m: m),
      );

  // ── UI Helpers ─────────────────────────────────────
  Widget _sheetHeader(IconData icon, String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: const BoxDecoration(
            color: primaryBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Row(children: [
          Icon(icon, color: primary),
          const SizedBox(width: 12),
          Text(title, style: m(16, FontWeight.w700, textDark))
        ]),
      );

  Widget _saveButton(VoidCallback onTap, String label) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
          child: Text(label, style: m(14, FontWeight.w700, Colors.white)),
        ),
      );

  Widget _sectionLabel(String label) =>
      Text(label, style: m(14, FontWeight.w700, textDark));

  Widget _whiteCard({required Widget child}) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ]),
        child: child,
      );

  Widget _divider() => const Divider(
      height: 1, indent: 52, endIndent: 16, color: Color(0xFFF0F0F0));

  Widget _settingsTile(
          {required IconData icon,
          required String title,
          String? subtitle,
          required VoidCallback onTap,
          bool showChevron = true}) =>
      Material(
          color: Colors.transparent,
          child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, color: textDark, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title, style: m(13, FontWeight.w600, textDark)),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(subtitle,
                                style: m(11, FontWeight.w500, textGrey))
                          ],
                        ])),
                    if (showChevron)
                      const Icon(Icons.chevron_right_rounded,
                          color: textGrey, size: 20),
                  ]))));

  Widget _deviceCard(
          {required IconData icon,
          required Color iconBg,
          required Color iconColor,
          required String name,
          required String statusLabel,
          required Color statusDot,
          required String detail}) =>
      Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: statusDot.withValues(alpha: 0.35), width: 1.4),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ]),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: iconColor, size: 24)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name, style: m(14, FontWeight.w700, textDark)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: statusDot, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(statusLabel, style: m(12, FontWeight.w600, statusDot))
                  ]),
                  const SizedBox(height: 4),
                  Text(detail, style: m(11, FontWeight.w500, textGrey)),
                ])),
          ]));

  Widget _notifRow(String label, bool value, ValueChanged<bool> onChanged) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
            color: cardBg, borderRadius: BorderRadius.circular(12)),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: m(13, FontWeight.w600, textDark)),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected) ? primary : Colors.white),
            trackColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected)
                    ? primary.withValues(alpha: 0.5)
                    : Colors.grey.withValues(alpha: 0.3)),
          ),
        ]),
      );

  Widget _outlineActionButton(
          {required String label,
          required IconData icon,
          required Color color,
          required VoidCallback onTap}) =>
      SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18, color: color),
            label: Text(label, style: m(14, FontWeight.w700, color)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: color, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
          ));
}

// ════════════════════════════════════════════════════════════
//  DELETE ACCOUNT DIALOG (separate widget to support async)
// ════════════════════════════════════════════════════════════
class _DeleteAccountDialog extends StatefulWidget {
  final TextStyle Function(double, FontWeight, Color) m;
  const _DeleteAccountDialog({required this.m});
  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  static const dangerRed = Color(0xFFE53935);
  static const textDark  = Color(0xFF1A1A1A);
  static const textGrey  = Color(0xFFAAAAAA);

  final _passwordCtrl = TextEditingController();
  bool _deleting   = false;
  bool _obscure    = true;
  String? _errorMsg;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final password = _passwordCtrl.text.trim();
    if (password.isEmpty) {
      setState(() => _errorMsg = 'Please enter your password to confirm');
      return;
    }

    setState(() { _deleting = true; _errorMsg = null; });

    try {
      final user  = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // ── Re-authenticate first (Firebase requirement for sensitive ops) ───
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);

      // ── Delete from our DB, then from Firebase ───────────────────────────
      await ApiService.delete(ApiConfig.deleteAccount);
      await user.delete();

      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _deleting  = false;
        _errorMsg  = e.code == 'wrong-password' || e.code == 'invalid-credential'
            ? 'Incorrect password — please try again'
            : e.message ?? 'Authentication failed';
      });
    } catch (e) {
      setState(() { _deleting = false; _errorMsg = 'Failed to delete account'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Icon + title ─────────────────────────────────────────────
            Container(
              width: 52, height: 52,
              decoration: const BoxDecoration(
                  color: Color(0xFFFFF0EE), shape: BoxShape.circle),
              child: const Icon(Icons.delete_forever_rounded,
                  color: dangerRed, size: 28),
            ),
            const SizedBox(height: 14),
            Text('Delete Account',
                style: m(18, FontWeight.w700, textDark),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'This will permanently remove your profile and all data. '
              'This cannot be undone.',
              style: m(13, FontWeight.w500, textGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // ── Password confirmation field ───────────────────────────────
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              enabled: !_deleting,
              decoration: InputDecoration(
                hintText: 'Enter your password to confirm',
                hintStyle: m(13, FontWeight.w400, textGrey),
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
              style: m(13, FontWeight.w500, textDark),
            ),

            // ── Error message ─────────────────────────────────────────────
            if (_errorMsg != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF0EE),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(_errorMsg!,
                    style: m(12, FontWeight.w500, dangerRed),
                    textAlign: TextAlign.center),
              ),
            ],

            const SizedBox(height: 20),

            // ── Buttons ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _deleting ? null : _confirmDelete,
                style: ElevatedButton.styleFrom(
                    backgroundColor: dangerRed, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50))),
                child: _deleting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Yes, Delete My Account',
                        style: m(14, FontWeight.w700, Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _deleting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Color(0xFFE0E0E0), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50))),
                child: Text('Cancel', style: m(14, FontWeight.w700, textDark)),
              ),
            ),
          ])),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  EDIT PERSONAL INFORMATION SCREEN
// ════════════════════════════════════════════════════════════
class EditPersonalInformationScreen extends StatefulWidget {
  final UserModel?    user;
  final ElderlyModel? elder;
  const EditPersonalInformationScreen({super.key, this.user, this.elder});
  @override
  State<EditPersonalInformationScreen> createState() =>
      _EditPersonalInformationScreenState();
}

class _EditPersonalInformationScreenState
    extends State<EditPersonalInformationScreen> {
  static const primary = Color(0xFF2FA884);
  static const primaryBg = Color(0xFFE6F4F0);
  static const bgColor = Color(0xFFF5F7F6);
  static const textDark = Color(0xFF1A1A1A);
  static const textGrey = Color(0xFFAAAAAA);
  static const cardBg = Color(0xFFFFFFFF);
  static const dangerRed = Color(0xFFE53935);

  static TextStyle m(double size, FontWeight weight, Color color) => TextStyle(
      fontFamily: 'Montserrat', fontSize: size, fontWeight: weight, color: color);

  // Caregiver fields
  final _cgFirstName = TextEditingController();
  final _cgLastName  = TextEditingController();
  final _cgPhone     = TextEditingController();
  final _cgEmail     = TextEditingController();
  String? _cgRelation;
  final _relations = ['Son', 'Daughter', 'Spouse', 'Sibling', 'Other'];

  // Elder fields
  final _elFirstName = TextEditingController();
  final _elLastName  = TextEditingController();
  final _elDob       = TextEditingController();
  String? _elGender;
  DateTime? _elDobDate;
  final _genders = ['Male', 'Female', 'Prefer not to say'];

  // Emergency
  final _emergName  = TextEditingController();
  final _emergPhone = TextEditingController();

  bool _saving = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    // Pre-fill caregiver fields
    final u = widget.user;
    if (u != null) {
      _cgFirstName.text = u.firstName;
      _cgLastName.text  = u.lastName;
      _cgPhone.text     = u.phone ?? '';
      _cgEmail.text     = u.email;
    }
    // Pre-fill elder fields
    final e = widget.elder;
    if (e != null) {
      _elFirstName.text = e.firstName;
      _elLastName.text  = e.lastName;
      if (e.dateOfBirth != null) {
        _elDobDate = e.dateOfBirth;
        final d = e.dateOfBirth!;
        _elDob.text = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
      }
      _elGender    = e.gender != null ? _capitalize(e.gender!) : null;
      _emergName.text  = e.emergencyContactName;
      _emergPhone.text = e.emergencyContactPhone;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  void dispose() {
    for (final c in [_cgFirstName, _cgLastName, _cgPhone, _cgEmail,
                     _elFirstName, _elLastName, _elDob, _emergName, _emergPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final cgFirst = _cgFirstName.text.trim();
    final cgLast  = _cgLastName.text.trim();
    if (cgFirst.isEmpty || cgLast.isEmpty) {
      setState(() => _errorMsg = 'First and last name are required');
      return;
    }
    setState(() { _saving = true; _errorMsg = null; });
    try {
      // Update caregiver profile
      await ApiService.put(ApiConfig.updateProfile, {
        'first_name': cgFirst,
        'last_name':  cgLast,
        if (_cgPhone.text.trim().isNotEmpty) 'phone': _cgPhone.text.trim(),
      });
      // Update elder profile if we have an ID
      final elderId = widget.elder?.id;
      if (elderId != null) {
        await ElderlyService.update(elderId, {
          'firstName':          _elFirstName.text.trim(),
          'lastName':           _elLastName.text.trim(),
          if (_elDobDate != null) 'dateOfBirth': _elDobDate,
          if (_elGender != null) 'gender': _elGender,
          'emergencyName':      _emergName.text.trim(),
          'emergencyPhone':     _emergPhone.text.trim(),
        });
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')));
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _errorMsg = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryBg, elevation: 0, surfaceTintColor: primaryBg,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark, size: 20),
            onPressed: () => Navigator.pop(context)),
        title: Text('Edit Personal Information', style: m(16, FontWeight.w700, textDark)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Caregiver Details ──────────────────────
          _sectionHeader(Icons.person_outline_rounded, 'Caregiver Details'),
          const SizedBox(height: 14),
          _field(_cgFirstName, 'First Name*', Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _field(_cgLastName, 'Last Name*', Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _field(_cgPhone, 'Phone Number', Icons.phone_outlined, type: TextInputType.phone),
          const SizedBox(height: 12),
          _field(_cgEmail, 'Email Address', Icons.mail_outline_rounded,
              type: TextInputType.emailAddress, readOnly: true),
          const SizedBox(height: 12),
          _dropdown('Relation to Elder', Icons.people_outline_rounded,
              _cgRelation, _relations, (v) => setState(() => _cgRelation = v)),

          const SizedBox(height: 28),

          // ── Elder Details ──────────────────────────
          if (widget.elder != null) ...[
            _sectionHeader(Icons.elderly_outlined, 'Elder Details'),
            const SizedBox(height: 14),
            _field(_elFirstName, 'First Name*', Icons.elderly_outlined),
            const SizedBox(height: 12),
            _field(_elLastName, 'Last Name*', Icons.elderly_outlined),
            const SizedBox(height: 12),
            _datePicker(_elDob, 'Date of Birth'),
            const SizedBox(height: 12),
            _dropdown('Gender', Icons.transgender_outlined, _elGender, _genders,
                (v) => setState(() => _elGender = v)),

            const SizedBox(height: 28),

            // ── Safety Information ─────────────────────
            _sectionHeader(Icons.shield_outlined, 'Safety Information'),
            const SizedBox(height: 14),
            _field(_emergName, "Emergency Contact's Name", Icons.person_outline_rounded),
            const SizedBox(height: 12),
            _field(_emergPhone, 'Emergency Contact Number', Icons.phone_outlined,
                type: TextInputType.phone),
            const SizedBox(height: 28),
          ],

          if (_errorMsg != null) ...[
            Text(_errorMsg!, style: m(12, FontWeight.w500, dangerRed)),
            const SizedBox(height: 12),
          ],

          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: primary, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Save Changes', style: m(15, FontWeight.w700, Colors.white)),
              )),
          const SizedBox(height: 36),
        ]),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) => Row(children: [
        Icon(icon, color: textDark, size: 20),
        const SizedBox(width: 8),
        Text(title, style: m(15, FontWeight.w700, textDark)),
      ]);

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: m(13, FontWeight.w500, textGrey),
        prefixIcon: Icon(icon, color: textGrey, size: 20),
        filled: true, fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 1.2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 1.2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primary, width: 1.5)),
      );

  Widget _field(TextEditingController c, String hint, IconData icon,
          {TextInputType type = TextInputType.text, bool readOnly = false}) =>
      TextField(
          controller: c, keyboardType: type, readOnly: readOnly,
          style: m(13, FontWeight.w500, readOnly ? textGrey : textDark),
          decoration: _dec(hint, icon));

  Widget _dropdown(String hint, IconData icon, String? value,
          List<String> items, ValueChanged<String?> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: value, onChanged: onChanged,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: textGrey),
        style: m(13, FontWeight.w500, textDark),
        decoration: _dec(hint, icon),
        items: items.map((e) => DropdownMenuItem(
            value: e, child: Text(e, style: m(13, FontWeight.w500, textDark)))).toList(),
      );

  Widget _datePicker(TextEditingController c, String hint) => TextField(
        controller: c, readOnly: true,
        style: m(13, FontWeight.w500, textDark),
        onTap: () async {
          final p = await showDatePicker(
            context: context,
            initialDate: _elDobDate ?? DateTime(1960),
            firstDate: DateTime(1900), lastDate: DateTime.now(),
            builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: primary, onPrimary: Colors.white)),
                child: child!),
          );
          if (p != null) {
            setState(() { _elDobDate = p; });
            c.text = '${p.day.toString().padLeft(2,'0')}/${p.month.toString().padLeft(2,'0')}/${p.year}';
          }
        },
        decoration: _dec(hint, Icons.calendar_today_outlined),
      );
}
