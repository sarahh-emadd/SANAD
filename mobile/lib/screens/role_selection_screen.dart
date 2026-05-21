import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Top Image (takes ~65% of screen) ──
          SizedBox(
            width: screenWidth,
            height: screenHeight * 0.65,
            child: Image.asset(
              'assets/images/elderorcaregiver.jpeg',
              fit: BoxFit.cover,
            ),
          ),

          // ── White curved bottom sheet ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: screenHeight * 0.42,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Title ──
                    Text(
                      'Who are you?',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose your role to get started',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textLight,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── I'm an Elder Button ──
                    _RoleButton(
                      label: "I'm an Elder",
                      filled: true,
                      onTap: () {
                        // TODO: Navigate to Elder login screen (handled by teammate)
                        // Navigator.push(context, MaterialPageRoute(builder: (_) => const ElderLoginScreen()));
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── I'm a Caregiver Button ──
                    _RoleButton(
                      label: "I'm a Caregiver",
                      filled: false,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: filled ? AppTheme.primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppTheme.primaryGreen,
              width: 2,
            ),
            boxShadow: filled
                ? [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : AppTheme.primaryGreen,
              ),
            ),
          ),
        ),
      ),
    );
  }
}