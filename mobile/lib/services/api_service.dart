import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';

class ApiService {
  // ── Get Firebase JWT token ─────────────────────────────────────────────────
  static Future<String?> _getToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  // ── Build headers ──────────────────────────────────────────────────────────
  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await _getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ── Parse response ─────────────────────────────────────────────────────────
  static Map<String, dynamic> _parse(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(
      statusCode: res.statusCode,
      message: body['message'] ?? 'Something went wrong',
    );
  }

  // ── GET ────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> get(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(ApiConfig.timeout);
      return _parse(res);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Server unreachable');
    }
  }

  // ── POST ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse(url),
            headers: await _headers(auth: auth),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);
      return _parse(res);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Server unreachable');
    }
  }

  // ── PUT ────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> put(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await http
          .put(
            Uri.parse(url),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);
      return _parse(res);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Server unreachable');
    }
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> delete(String url) async {
    try {
      final res = await http
          .delete(Uri.parse(url), headers: await _headers())
          .timeout(ApiConfig.timeout);
      return _parse(res);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Server unreachable');
    }
  }
}

// ── Custom exception ──────────────────────────────────────────────────────────
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException({this.statusCode, required this.message});

  @override
  String toString() => message;

  bool get isUnauthorized  => statusCode == 401;
  bool get isNotFound      => statusCode == 404;
  bool get isConflict      => statusCode == 409;
  bool get isServerError   => (statusCode ?? 0) >= 500;
}
