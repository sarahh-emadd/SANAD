import 'package:flutter/material.dart';
import 'package:sanad_app/constants/app_colors.dart';
import 'package:sanad_app/screens/pages/welcome_elder_page.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [

          /// 🔹 IMAGE SECTION
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            width: double.infinity,
            child: Stack(
              children: [

                /// Full Image
                Positioned.fill(
                  child: Image.asset(
                    'assets/elder_caregiver.png',
                    fit: BoxFit.cover,
                  ),
                ),

                /// White curved container overlapping image
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(50),
                        topRight: Radius.circular(50),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// 🔹 BUTTON SECTION
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [

                  const SizedBox(height: 20),

                  /// 🔹 TEXT SECTION
                  const Text(
                    'Who are you?',
                    style: TextStyle(
                      color: Color(0xFF2A504C),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose your role to Get Started',
                    style: TextStyle(
                      color: Color(0xFF7A9E9B),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// 🔹 FILLED BUTTON (Elder)
                  buildFilledButton("I'm an Elder", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WelcomeElderPage(),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),

                  /// 🔹 OUTLINED BUTTON (Caregiver)
                  buildOutlinedButton("I'm a Caregiver", () {
                    // Add navigation for caregiver later
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Filled green button with white text
  Widget buildFilledButton(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          color: const Color(0xFF2FA884),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2FA884).withOpacity(0.35),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// Outlined button
  Widget buildOutlinedButton(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFF2FA884),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF2FA884),
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}