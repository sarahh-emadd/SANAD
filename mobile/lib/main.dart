import 'package:flutter/material.dart';
import 'package:sanad_app/screens/onboarding/onboarding_wrapper.dart';

void main() {
  runApp(const SanadApp());
}

class SanadApp extends StatelessWidget {
  const SanadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sanad App',
      theme: ThemeData(
        primaryColor: const Color(0xFF2A504C),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        fontFamily: 'Montserrat', // ← ضيفي السطر ده
        useMaterial3: true,
      ),

      home: const OnboardingWrapper(),
    );
  }
}