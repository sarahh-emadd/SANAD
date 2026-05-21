import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_settings_provider.dart';
import '../../services/auth_service.dart';
import '../role_selection_page.dart';

class ElderSettingsScreen extends StatefulWidget {
  const ElderSettingsScreen({super.key});

  @override
  State<ElderSettingsScreen> createState() => _ElderSettingsScreenState();
}

class _ElderSettingsScreenState extends State<ElderSettingsScreen> {
  static const primary    = Color(0xFF2FA884);
  static const primaryBg  = Color(0xFFE6F4F0);
  static const dangerRed  = Color(0xFFE53935);
  static const bgColor    = Color(0xFFF5F7F6);
  static const textDark   = Color(0xFF1A1A1A);
  static const textGrey   = Color(0xFFAAAAAA);
  static const cardBg     = Color(0xFFF7F7F7);

  static TextStyle m(double size, FontWeight weight, Color color) =>
      TextStyle(fontFamily: 'Montserrat', fontSize: size, fontWeight: weight, color: color);

  bool _notifAll        = true;
  bool _notifMessages   = true;
  bool _notifReminder   = true;
  bool _notifMedication = true;

  String _elderName     = '';
  String _caregiverName = '';
  String? _elderlyId;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _elderName     = prefs.getString('elderly_name')    ?? '';
      _caregiverName = prefs.getString('caregiver_name')  ?? '';
      _elderlyId     = prefs.getString('elderly_id');
    });
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark, size: 20),
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Accessibility ──────────────────────
              _sectionLabel('Accessibility'),
              const SizedBox(height: 10),
              _whiteCard(child: Column(children: [
                _settingsTile(
                  icon: Icons.volume_up_outlined,
                  title: 'Volume',
                  subtitle: settings.volumeLabel,
                  onTap: _showVolumeSheet,
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.text_fields_rounded,
                  title: 'Text Size',
                  subtitle: '${settings.textSize} (Current)',
                  onTap: _showTextSizeSheet,
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: _notifAll ? 'All Enabled' : 'Some Disabled',
                  onTap: _showNotificationsSheet,
                ),
              ])),

              const SizedBox(height: 20),

              // ── Connected Devices ──────────────────
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

              const SizedBox(height: 20),

              // ── Need Help? ─────────────────────────
              _sectionLabel('Need Help?'),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE8F8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Call your Caregiver or send voice message', style: m(13, FontWeight.w600, textDark)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onCallCaregiver,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: textDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      ),
                      child: Text('Call Caregiver', style: m(14, FontWeight.w700, textDark)),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Privacy & Security ─────────────────
              _sectionLabel('Privacy & Security'),
              const SizedBox(height: 10),
              _whiteCard(child: Column(children: [
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
              ])),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showSignOutDialog,
                  icon: const Icon(Icons.logout_rounded, size: 18, color: dangerRed),
                  label: Text('Sign Out', style: m(14, FontWeight.w700, dangerRed)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: dangerRed, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                ),
              ),
              const SizedBox(height: 36),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Sign Out Dialog ────────────────────────────────
  void _showSignOutDialog() => showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sign out', style: m(18, FontWeight.w700, textDark)),
            const SizedBox(height: 10),
            Text('Are you sure you want to sign out?', style: m(13, FontWeight.w500, textGrey)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                child: Text('Cancel', style: m(14, FontWeight.w700, textDark)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await AuthService.signOut();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: primary, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                child: Text('Sign Out', style: m(14, FontWeight.w700, Colors.white)),
              )),
            ]),
          ])),
    ),
  );

  // ── Profile Card ───────────────────────────────────
  Widget _buildProfileCard() {
    final displayName  = _elderName.isNotEmpty ? _elderName : 'Elder';
    final cgLine       = _caregiverName.isNotEmpty
        ? 'Connected to $_caregiverName (Caregiver)'
        : 'Not connected';
    final avatarLetter = displayName[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(
                builder: (_) => ElderEditPersonalInfoScreen(
                    elderName: _elderName, elderlyId: _elderlyId)));
            _loadNames();
          },
          child: Row(children: [
            CircleAvatar(radius: 26, backgroundColor: const Color(0xFFFFE0B2),
                child: Text(avatarLetter, style: m(20, FontWeight.w700, const Color(0xFFE65100)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(displayName, style: m(15, FontWeight.w700, textDark)),
              const SizedBox(height: 3),
              Text(cgLine, style: m(12, FontWeight.w500, textGrey)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: textGrey),
          ]),
        ),
      ),
    );
  }

  // ── Call Caregiver ─────────────────────────────────
  void _onCallCaregiver() {
    final cgName = _caregiverName.isNotEmpty ? _caregiverName : 'Caregiver';
    showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(padding: const EdgeInsets.fromLTRB(24, 28, 24, 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 24, backgroundColor: const Color(0xFFFFE0B2),
              child: Text(cgName[0].toUpperCase(), style: m(18, FontWeight.w700, const Color(0xFFE65100)))),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cgName, style: m(16, FontWeight.w700, textDark)),
            Text('Your Caregiver', style: m(12, FontWeight.w500, textGrey)),
          ]),
        ]),
        const SizedBox(height: 16),
        Text('Would you like to call your caregiver?', style: m(13, FontWeight.w500, textGrey)),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
            child: Text('Cancel', style: m(14, FontWeight.w700, textDark)),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.phone, size: 18, color: Colors.white),
            label: Text('Call', style: m(14, FontWeight.w700, Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: dangerRed, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
          )),
        ]),
      ])),
    ),
    );
  }

  // ── Volume Sheet ───────────────────────────────────
  void _showVolumeSheet() {
    double tempVolume = context.read<AppSettingsProvider>().volume;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setSS) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _sheetHeader(Icons.volume_up_outlined, 'Volume'),
          Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 36), child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Low',    style: m(12, FontWeight.w500, textGrey)),
              Text('Medium', style: m(12, FontWeight.w500, textGrey)),
              Text('High',   style: m(12, FontWeight.w500, textGrey)),
            ]),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(ctx).copyWith(
                activeTrackColor: textDark,
                inactiveTrackColor: const Color(0xFFE0E0E0),
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                overlayColor: Colors.black.withValues(alpha: 0.08),
                trackHeight: 10,
              ),
              child: Slider(value: tempVolume, min: 0, max: 1, divisions: 2, onChanged: (v) => setSS(() => tempVolume = v)),
            ),
            const SizedBox(height: 20),
            _saveButton(() {
              context.read<AppSettingsProvider>().setVolume(tempVolume);
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setSS) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _sheetHeader(Icons.text_fields_rounded, 'Text Size'),
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), child: Column(
            children: options.map((opt) {
              final isCurrent = opt == context.read<AppSettingsProvider>().textSize;
              return GestureDetector(
                onTap: () {
                  context.read<AppSettingsProvider>().setTextSize(opt);
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
                  child: Text(
                    isCurrent ? '$opt (current)' : opt,
                    style: m(14, isCurrent ? FontWeight.w700 : FontWeight.w600, isCurrent ? primary : textDark),
                  ),
                ),
              );
            }).toList(),
          )),
        ]),
      )),
    );
  }

  // ── Notifications Sheet ────────────────────────────
  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setSS) {
        void sync(VoidCallback fn) { setSS(fn); setState(fn); }
        void toggleAll(bool v) => sync(() {
          _notifAll = v; _notifMessages = v; _notifReminder = v; _notifMedication = v;
        });
        void recalc() => sync(() {
          _notifAll = _notifMessages && _notifReminder && _notifMedication;
        });
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHeader(Icons.notifications_outlined, 'Notifications'),
            Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), child: Column(children: [
              _notifRow('All Enabled',       _notifAll,        (v) => toggleAll(v)),
              _notifRow('Messages',          _notifMessages,   (v) { sync(() => _notifMessages   = v); recalc(); }),
              _notifRow('Medication Reminder', _notifReminder, (v) { sync(() => _notifReminder   = v); recalc(); }),
              _notifRow('Missed Medication', _notifMedication, (v) { sync(() => _notifMedication = v); recalc(); }),
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
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            _sheetHeader(Icons.shield_outlined, 'Privacy Settings'),
            Expanded(child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _privacySection('📍 Location Data', [
                  'SANAD collects your GPS location to help your caregiver ensure your safety.',
                  'Location is only shared with your connected caregiver and is never shared with third parties.',
                  'Location tracking helps detect if you have left a safe zone or need assistance.',
                ]),
                const SizedBox(height: 20),
                _privacySection('📷 Camera & Monitoring', [
                  'The health camera monitors your environment to detect falls or unusual activity.',
                  'Camera footage is only accessible to your authorized caregiver.',
                  'No footage is shared with third parties or used for any other purpose.',
                ]),
                const SizedBox(height: 20),
                _privacySection('💊 Medication Data', [
                  'SANAD tracks your medication schedule using the smart pillbox sensor.',
                  'This data is used solely to help your caregiver monitor your health and wellbeing.',
                ]),
                const SizedBox(height: 20),
                _privacySection('👤 Personal Information', [
                  'We collect basic personal details to provide a personalized care experience.',
                  'Your data is never sold or shared with advertisers.',
                  'You can request deletion of your data at any time.',
                ]),
                const SizedBox(height: 20),
                _privacySection('🔒 Data Security', [
                  'All your data is encrypted in transit and at rest.',
                  'Only you and your connected caregiver can access your information.',
                ]),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFE6F4F0), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    'SANAD is an academic graduation project. Your data is collected solely to provide care and monitoring services.',
                    style: m(12, FontWeight.w500, primary),
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
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            _sheetHeader(Icons.description_outlined, 'Terms and Conditions'),
            Expanded(child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _privacySection('1. Acceptance of Terms', [
                  'By using SANAD, you agree to these Terms and Conditions.',
                  'SANAD is an academic graduation project designed to assist in elder care monitoring.',
                ]),
                const SizedBox(height: 20),
                _privacySection('2. Use of the Application', [
                  'SANAD is intended to be used by you and your authorized caregiver only.',
                  'The caregiver is responsible for ensuring your consent before enabling monitoring features.',
                ]),
                const SizedBox(height: 20),
                _privacySection('3. Monitoring & Privacy', [
                  'Camera monitoring, location tracking, and medication monitoring are designed purely for your safety.',
                  'All monitoring data is only visible to your connected caregiver.',
                ]),
                const SizedBox(height: 20),
                _privacySection('4. Data Responsibility', [
                  'You are responsible for keeping your login credentials secure.',
                  'SANAD stores data securely and does not share it with any third parties.',
                ]),
                const SizedBox(height: 20),
                _privacySection('5. Limitation of Liability', [
                  'SANAD does not replace professional medical advice or emergency services.',
                  'In case of a medical emergency, always contact emergency services immediately.',
                ]),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFE6F4F0), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    'Last updated: May 2025 · SANAD Graduation Project Team',
                    style: m(12, FontWeight.w500, primary),
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
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('• ', style: m(13, FontWeight.w500, primary)),
          Expanded(child: Text(p, style: m(13, FontWeight.w500, const Color(0xFF444444)))),
        ]),
      )),
    ],
  );

  // ── UI Helpers ─────────────────────────────────────
  Widget _sheetHeader(IconData icon, String title) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    decoration: const BoxDecoration(color: primaryBg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    child: Row(children: [Icon(icon, color: primary), const SizedBox(width: 12), Text(title, style: m(16, FontWeight.w700, textDark))]),
  );

  Widget _saveButton(VoidCallback onTap, String label) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: primary, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      child: Text(label, style: m(14, FontWeight.w700, Colors.white)),
    ),
  );

  Widget _sectionLabel(String label) => Text(label, style: m(14, FontWeight.w700, textDark));

  Widget _whiteCard({required Widget child}) => Container(
    width: double.infinity,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]),
    child: child,
  );

  Widget _divider() => const Divider(height: 1, indent: 52, endIndent: 16, color: Color(0xFFF0F0F0));

  Widget _settingsTile({required IconData icon, required String title, String? subtitle, required VoidCallback onTap, bool showChevron = true}) =>
      Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: textDark, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: m(13, FontWeight.w600, textDark)),
              if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: m(11, FontWeight.w500, textGrey))],
            ])),
            if (showChevron) const Icon(Icons.chevron_right_rounded, color: textGrey, size: 20),
          ]))));

  Widget _deviceCard({required IconData icon, required Color iconBg, required Color iconColor, required String name, required String statusLabel, required Color statusDot, required String detail}) =>
      Container(width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: statusDot.withValues(alpha: 0.35), width: 1.4),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))]),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: iconColor, size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: m(14, FontWeight.w700, textDark)),
              const SizedBox(height: 4),
              Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: statusDot, shape: BoxShape.circle)), const SizedBox(width: 6), Text(statusLabel, style: m(12, FontWeight.w600, statusDot))]),
              const SizedBox(height: 4),
              Text(detail, style: m(11, FontWeight.w500, textGrey)),
            ])),
          ]));

  Widget _notifRow(String label, bool value, ValueChanged<bool> onChanged) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: m(13, FontWeight.w600, textDark)),
      Switch.adaptive(value: value, onChanged: onChanged,
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3)),
      ),
    ]),
  );
}


// ════════════════════════════════════════════════════════════
//  ELDER EDIT PERSONAL INFO SCREEN
// ════════════════════════════════════════════════════════════
class ElderEditPersonalInfoScreen extends StatefulWidget {
  final String  elderName;
  final String? elderlyId;
  const ElderEditPersonalInfoScreen({super.key, required this.elderName, this.elderlyId});
  @override
  State<ElderEditPersonalInfoScreen> createState() => _ElderEditPersonalInfoScreenState();
}

class _ElderEditPersonalInfoScreenState extends State<ElderEditPersonalInfoScreen> {
  static const primary   = Color(0xFF2FA884);
  static const primaryBg = Color(0xFFE6F4F0);
  static const bgColor   = Color(0xFFF5F7F6);
  static const textDark  = Color(0xFF1A1A1A);
  static const textGrey  = Color(0xFFAAAAAA);
  static const cardBg    = Color(0xFFFFFFFF);

  static TextStyle m(double size, FontWeight weight, Color color) =>
      TextStyle(fontFamily: 'Montserrat', fontSize: size, fontWeight: weight, color: color);

  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from the name stored in SharedPreferences
    final parts = widget.elderName.trim().split(' ');
    _firstName.text = parts.isNotEmpty ? parts.first : '';
    _lastName.text  = parts.length > 1  ? parts.sublist(1).join(' ') : '';
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final first = _firstName.text.trim();
    final last  = _lastName.text.trim();
    if (first.isEmpty) return;
    setState(() => _saving = true);
    // Save display name locally (elder cannot update the backend profile without caregiver auth)
    final prefs = await SharedPreferences.getInstance();
    final newName = last.isNotEmpty ? '$first $last' : first;
    await prefs.setString('elderly_name', newName);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Display name updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryBg, elevation: 0, surfaceTintColor: primaryBg,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Edit Personal Information', style: m(16, FontWeight.w700, textDark)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Personal Details', style: m(15, FontWeight.w700, textDark)),
          const SizedBox(height: 6),
          Text('To update your full profile, ask your caregiver to edit it in their app.',
              style: m(12, FontWeight.w500, textGrey)),
          const SizedBox(height: 14),
          _field(_firstName, 'First Name*', Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _field(_lastName,  'Last Name',   Icons.person_outline_rounded),

          const SizedBox(height: 32),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: primary, elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Save Changes', style: m(15, FontWeight.w700, Colors.white)),
          )),
          const SizedBox(height: 36),
        ]),
      ),
    );
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
    hintText: hint, hintStyle: m(13, FontWeight.w500, textGrey),
    prefixIcon: Icon(icon, color: textGrey, size: 20),
    filled: true, fillColor: cardBg, contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 1.2)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 1.2)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primary, width: 1.5)),
  );

  Widget _field(TextEditingController c, String hint, IconData icon, {TextInputType type = TextInputType.text}) =>
      TextField(controller: c, keyboardType: type, style: m(13, FontWeight.w500, textDark), decoration: _dec(hint, icon));
}