import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OnboardingPage5 extends StatelessWidget {
  const OnboardingPage5({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Column(
        children: [
          // النص فوق
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                SizedBox(height: 60),

                Text(
                  'Easy Daily Health Check',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2A504C),
                    height: 1.4,
                  ),
                ),

                SizedBox(height: 24),

                Text(
                  'Simple check-ins helps your\ncaregiver know you\'re doing\nwell',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF2A504C),
                    height: 1.5,
                  ),
                ),

                SizedBox(height: 24),
              ],
            ),
          ),

          // الصورة مع الـ green circle
          Expanded(
            child: Stack(
              children: [
                // Mint green circle
                Positioned(
                  top: screenHeight * 0.02,
                  left: -screenWidth * 0.05,
                  right: -screenWidth * 0.05,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFD3EFE4),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(300),
                        topRight:Radius.circular(300),
                      ),
                    ),
                  ),
                ),

                // الصورة
                Positioned(
                  top: screenHeight * 0.02,
                  left: -screenWidth * 0.05,
                  right: -screenWidth * 0.05,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(300),
                      topRight: Radius.circular(300),
                    ),
                    child: Image.asset(
                      'assets/health_check.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFD3EFE4),
                          child: Icon(
                            Icons.health_and_safety,
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
        ],
      ),
    );
  }
}