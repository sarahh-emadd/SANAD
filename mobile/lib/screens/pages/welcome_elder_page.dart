import 'package:flutter/material.dart';
import 'package:sanad_app/constants/app_colors.dart';
import 'package:sanad_app/screens/pages/qr_scanner_page.dart';

class WelcomeElderPage extends StatelessWidget {
  const WelcomeElderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF2A504C),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const SizedBox(height: 60),

            /// Welcome Text
            const Text(
              'Welcome to\nSanad',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2A504C),
                height: 1.3,
              ),
            ),

            const SizedBox(height: 20),

            /// Subtitle
            const Text(
              "Let's connect you with your Caregiver",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2A504C),
              ),
            ),

            const SizedBox(height: 50),

            /// Image with mint green circle background
            Stack(
              alignment: Alignment.center,
              children: [
                /// Mint green circle
                Container(
                  width: 307,
                  height: 293,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBECDF), // Mint green
                    shape: BoxShape.circle,
                  ),
                ),

                /// Elder image
                Transform.translate(
                  offset: const Offset(0, -30), // photo up
                  child: Image.asset(
                    'assets/elder_image.png',
                    width: 270,
                    height: 370,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 80),

            /// Scan QR Code Button
            InkWell(
              onTap: () {
                // Navigate to QR scanner page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QRScannerPage(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: 240,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF2FA884),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'Scan QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}