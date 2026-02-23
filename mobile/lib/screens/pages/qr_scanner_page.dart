import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController cameraController = MobileScannerController();

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

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
      body: Container(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            const SizedBox(height: 20),

            /// Title
            const Text(
              'Connect with\nCaregiver',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2A504C),
                height: 1.3,
              ),
            ),

            const SizedBox(height: 40),

            /// QR Scanner Camera
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF2A504C),
                  width: 3,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        // QR Code detected
                        debugPrint('QR Code found: ${barcode.rawValue}');
                        // Navigate to next page or process the code
                        // Navigator.push(context, ...);
                      }
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 30),

            /// Instruction Text
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Point Camera at Your\nCaregiver\'s QR Code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2A504C),
                  height: 1.4,
                ),
              ),
            ),

            const Spacer(),

            /// Having trouble button
            InkWell(
              onTap: () {
                // Navigate to enter code manually page
                _showEnterCodeDialog(context);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 240,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF2FA884),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'Having trouble? Enter Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// Next Button
            InkWell(
              onTap: () {
                // Navigate to next page
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 240,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF2A504C),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Next',
                    style: TextStyle(
                      color: Color(0xFF2A504C),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showEnterCodeDialog(BuildContext context) {
    TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Enter Caregiver Code',
          style: TextStyle(
            color: Color(0xFF2A504C),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            hintText: 'Enter code here',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              // Process the entered code
              String code = codeController.text;
              debugPrint('Entered code: $code');
              Navigator.pop(context);
              // Navigate to next page or verify code
            },
            child: const Text(
              'Submit',
              style: TextStyle(color: Color(0xFF2FA884)),
            ),
          ),
        ],
      ),
    );
  }
}