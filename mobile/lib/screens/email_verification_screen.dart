import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'elder_profile_step1_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String password;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _checkTimer;
  Timer? _resendTimer;
  int _resendCooldown = 0;
  bool _isChecking = false;
  User? _user;

  @override
  void initState() {
    super.initState();
    _initAndSendEmail();
    _checkTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _checkVerification());
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  /// Re-authenticate if currentUser is null (macOS keychain drops session)
  /// then send verification email.
  Future<void> _initAndSendEmail() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        // Session was lost — sign in again to restore it
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: widget.email,
          password: widget.password,
        );
        user = cred.user;
      }

      _user = user;

      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        print('📧 Verification email sent to ${user.email}');
      }
    } catch (e) {
      print('❌ Init/send error: $e');
    }
  }

  Future<void> _checkVerification() async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      final user = _user ?? FirebaseAuth.instance.currentUser;
      await user?.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed != null && refreshed.emailVerified) {
        _checkTimer?.cancel();
        if (!mounted) return;
        // New user — always go through elder profile setup before home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ElderProfileStep1Screen()),
        );
      }
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _resendEmail() async {
    try {
      User? user = _user ?? FirebaseAuth.instance.currentUser;

      if (user == null) {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: widget.email,
          password: widget.password,
        );
        user = cred.user;
        _user = user;
      }

      await user?.sendEmailVerification();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Verification email sent!',
            style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      setState(() => _resendCooldown = 60);
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _resendCooldown--);
        if (_resendCooldown <= 0) t.cancel();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to send email. Please try again.',
            style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _signOut,
            child: Text('Sign Out',
                style:
                    GoogleFonts.inter(color: AppTheme.textLight, fontSize: 14)),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 52,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Verify Your Email',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "We've sent a verification link to",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppTheme.textLight, height: 1.6),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please check your inbox and click the link\nto activate your account.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppTheme.textLight, height: 1.6),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryGreen.withAlpha(150),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Waiting for verification...',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppTheme.textLight)),
                  ],
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _resendCooldown > 0 ? null : _resendEmail,
                    child: Text(
                      _resendCooldown > 0
                          ? 'Resend in ${_resendCooldown}s'
                          : 'Resend Verification Email',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _checkVerification,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppTheme.primaryGreen, width: 1.8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text("I've Verified My Email",
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGreen,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
