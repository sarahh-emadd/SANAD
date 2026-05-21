import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  // ── Sign Up ────────────────────────────────────────────────────────────────
  static Future<UserModel> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
  }) async {
    // 1. Create Firebase account
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 2. Send verification email
    try {
      await cred.user!.sendEmailVerification();
    } catch (e) {
      // Keychain errors can happen on macOS during email send — ignore,
      // the account is created and we continue
      if (!_isKeychainError(e)) rethrow;
    }

    // 3. Sync to backend database
    try {
      final res = await ApiService.post(
        ApiConfig.syncUser,
        {
          'firebase_uid': cred.user!.uid,
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
        },
        auth: false,
      );

      // 4. Parse and save user locally
      final user = UserModel.fromJson(res['data']['user']);
      await StorageService.saveUser(user);
      return user;
    } catch (e) {
      // If it's a keychain error, the account was still created in Firebase.
      // Don't delete it — just rethrow so the UI can handle navigation.
      if (_isKeychainError(e)) rethrow;

      // For real backend errors, delete the Firebase account so user can retry
      await cred.user?.delete();
      rethrow;
    }
  }

  // ── Log In ─────────────────────────────────────────────────────────────────
  static Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    // 1. Sign in with Firebase
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 2. Check email is verified
    if (!cred.user!.emailVerified) {
      await _auth.signOut();
      throw ApiException(
        statusCode: 403,
        message: 'Please verify your email before logging in.',
      );
    }

    // 3. Force fresh token so backend accepts it
    await cred.user!.getIdToken(true);

    // 4. Fetch user from backend
    final res = await ApiService.get(ApiConfig.getMe);
    final user = UserModel.fromJson(res['data']['user']);

    // 5. Save locally
    await StorageService.saveUser(user);
    return user;
  }

  // ── Forgot Password ────────────────────────────────────────────────────────
  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Get current user from backend ──────────────────────────────────────────
  static Future<UserModel> getMe() async {
    final res = await ApiService.get(ApiConfig.getMe);
    final user = UserModel.fromJson(res['data']['user']);
    await StorageService.saveUser(user);
    return user;
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    await _auth.signOut();
    await StorageService.clearAll();
  }

  // ── Check if user is logged in ─────────────────────────────────────────────
  static bool get isLoggedIn => _auth.currentUser != null;

  // ── Check if email is verified ─────────────────────────────────────────────
  static bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // ── Get saved user from local storage ─────────────────────────────────────
  static Future<UserModel?> getSavedUser() => StorageService.getUser();

  // ── Helper: detect macOS keychain errors ──────────────────────────────────
  static bool _isKeychainError(dynamic e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('keychain') ||
        msg.contains('nslocalizedfailurereasonerrork') ||
        (e is FirebaseAuthException && e.code == 'keychain-error');
  }
}
