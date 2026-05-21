import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OnboardingPage4 extends StatelessWidget {
  const OnboardingPage4({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Column(
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
                      bottomLeft: Radius.circular(300),
                      bottomRight: Radius.circular(300),
                    ),
                  ),
                ),

                // الصورة تملا الـ background
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(300),
                      bottomRight: Radius.circular(300),
                    ),
                    child: Image.asset(
                      'assets/elderly_camera.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.transparent,
                          child: Icon(
                            Icons.camera_alt,
                            size: 100,
                            color: Colors.grey.shade500,
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
          const Expanded(
            flex: 4,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 20),

                  Text(
                    '24/7 Safety & Privacy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2A504C),
                      height: 1.3,
                    ),
                  ),

                  SizedBox(height: 16),

                  Text(
                    'Our camera keeps you safe at home\nwhile fully respecting your privacy,\nproviding round-the-clock security and\npeace of mind',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF2A504C),
                      height: 1.5,
                    ),
                  ),

                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}