import 'package:flutter/material.dart';

class OnboardingPage3 extends StatelessWidget {
  const OnboardingPage3({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // Mint green circle section - covers bottom half+
          Positioned(
            top: screenHeight * 0.32,
            left: -screenWidth * 0.05,
            right: -screenWidth * 0.05,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFD3EFE4),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(300),
                  topRight: Radius.circular(300),
                ),
              ),
            ),
          ),

          // Main content
          Column(
            children: [
              const SizedBox(height: 60),

              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Never Miss a medication Again',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2A504C),
                    height: 1.4,

                    decorationColor: Color(0xFF2A504C),
                    decorationThickness: 2,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Description
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Your smart pillbox lights up\nwhen its time to take your\nmedicine',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color:  Color(0xFF2A504C),
                    height: 1.5,
                  ),
                ),
              ),

              const Spacer(),

              // Pillbox Image
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Image.asset(
                  'assets/pillbox_image.png',
                  width: 500,
                  height: 500,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 500,
                      height: 500,
                      color: Colors.transparent,
                      child: Icon(
                        Icons.medication,
                        size: 200,
                        color: Colors.grey.shade400,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 140), // Space for navigation
            ],
          ),
        ],
      ),
    );
  }
}