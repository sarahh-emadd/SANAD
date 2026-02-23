import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sanad_app/screens/elder_profile_step1_screen.dart';
import 'theme/app_theme.dart';
import 'screens/role_selection_screen.dart';
import 'screens/elder_profile_step1_screen.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(const SanadApp());
}

class SanadApp extends StatelessWidget {
  const SanadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sanad',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const ElderProfileStep1Screen(),
    );
  }
}

