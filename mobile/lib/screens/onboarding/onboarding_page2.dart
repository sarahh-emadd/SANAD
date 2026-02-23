import 'package:flutter/material.dart';

class OnboardingPage2 extends StatelessWidget {
  const OnboardingPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top curved background section with image
        Expanded(
          flex: 6,
          child: Stack(
            children: [
              // Curved background
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFD3EFE4),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(200),
                    bottomRight: Radius.circular(200),
                  ),
                ),
              ),
              // Image on top of background
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Image.asset(
                    'assets/onbone.png',
                    width: 500,
                    height: 500,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 500,
                        height: 500,
                        color: Colors.transparent,
                        child: Icon(
                          Icons.phone_android,
                          size: 200,
                          color: Colors.grey.shade400,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom section with text
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Stay Connected With\nYour Caregiver',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2A504C),
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 20),

                // Description
                const Text(
                  'Your family can check on you\nanytime and send loving voice\nmessages',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color:  Color(0xFF2A504C),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }
}