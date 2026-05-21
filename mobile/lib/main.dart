import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_settings_provider.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding/onboarding_wrapper.dart';
import 'screens/role_selection_page.dart';
import 'screens/caregiver_home_screen.dart';
import 'screens/pages/home_elder_page.dart';

/// Background / terminated handler — must be a top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Determines the correct starting screen based on SharedPreferences state.
///
/// Logic:
///   1. If onboarding not done      → OnboardingWrapper
///   2. If role not saved yet        → RoleSelectionPage
///   3. If role == 'caregiver'       → CaregiverHomeScreen
///   4. If role == 'elder'           → HomeElderPage
Future<Widget> _resolveStartScreen() async {
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

  if (!onboardingDone) return const OnboardingWrapper();

  final role = prefs.getString('user_role');

  if (role == 'caregiver') return const CaregiverHomeScreen();
  if (role == 'elder') return const HomeElderPage();

  return const RoleSelectionPage();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  final startScreen = await _resolveStartScreen();

  runApp(SanadApp(startScreen: startScreen));
}

class SanadApp extends StatefulWidget {
  final Widget startScreen;
  const SanadApp({super.key, required this.startScreen});

  @override
  State<SanadApp> createState() => _SanadAppState();
}

class _SanadAppState extends State<SanadApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupFCMListeners();
  }

  void _setupFCMListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      _showForegroundBanner(
        title: notification.title ?? 'SANAD Alert',
        body: notification.body ?? '',
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Navigate to notifications screen on tap
    });
  }

  void _showForegroundBanner({required String title, required String body}) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            if (body.isNotEmpty)
              Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppSettingsProvider>(
      create: (_) => AppSettingsProvider(),
      child: MaterialApp(
        title: 'Sanad',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: _navigatorKey,
        home: widget.startScreen,
      ),
    );
  }
}
