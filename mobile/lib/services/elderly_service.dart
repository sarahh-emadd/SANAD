import '../config/api_config.dart';
import '../models/elderly_model.dart';
import '../models/qr_model.dart';
import 'api_service.dart';

class ElderlyService {
  // ── Create profile (sends all 4 steps data) ────────────────────────────────
  static Future<Map<String, dynamic>> createProfile(
    Map<String, dynamic> formData,
  ) async {
    final body = ElderlyModel.toRequestBody(formData);
    final res = await ApiService.post(ApiConfig.createElderly, body);
    final data = res['data'];

    return {
      'elderly':       ElderlyModel.fromJson(data['elderly']),
      'qrCodeImage':   data['qrCodeImage'],   // base64 PNG string
      'manualCode':    data['manualCode'],     // 6-digit code
      'expiresAt':     data['expiresAt'],
      'expiresIn':     data['expiresIn'],
    };
  }

  // ── Get all elderly for current caregiver ──────────────────────────────────
  static Future<List<ElderlyModel>> getAll() async {
    final res = await ApiService.get(ApiConfig.getAllElderly);
    final list = res['data']['elderly'] as List;
    return list.map((e) => ElderlyModel.fromJson(e)).toList();
  }

  // ── Get single elderly by ID ───────────────────────────────────────────────
  static Future<ElderlyModel> getById(String id) async {
    final res = await ApiService.get(ApiConfig.elderlyById(id));
    return ElderlyModel.fromJson(res['data']['elderly']);
  }

  // ── Get elderly with QR code ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> getWithQR(String id) async {
    final res = await ApiService.get(ApiConfig.elderlyQR(id));
    final data = res['data'];
    return {
      'elderly':          ElderlyModel.fromJson(data['elderly']),
      'qr':               data['qr'] != null
          ? QrModel.fromJson(data['qr']['qrToken'])
          : null,
      'qrCodeImage':      data['qr']?['qrCodeImage'],
      'manualCode':       data['qr']?['manualCode'],
      'needsRegeneration': data['needsRegeneration'] ?? true,
    };
  }

  // ── Regenerate QR code ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> regenerateQR(String id) async {
    final res = await ApiService.post(ApiConfig.regenerateQR(id), {});
    final data = res['data'];
    return {
      'elderly':     ElderlyModel.fromJson(data['elderly']),
      'qrCodeImage': data['qrCodeImage'],
      'manualCode':  data['manualCode'],
      'expiresAt':   data['expiresAt'],
      'expiresIn':   data['expiresIn'],
    };
  }

  // ── Update elderly profile ─────────────────────────────────────────────────
  static Future<ElderlyModel> update(
    String id,
    Map<String, dynamic> formData,
  ) async {
    final body = ElderlyModel.toRequestBody(formData);
    final res = await ApiService.put(ApiConfig.updateElderly(id), body);
    return ElderlyModel.fromJson(res['data']['elderly']);
  }

  // ── Delete elderly (archive) ───────────────────────────────────────────────
  static Future<void> delete(String id) async {
    await ApiService.delete(ApiConfig.deleteElderly(id));
  }

  // ── Get dashboard stats ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getStats() async {
    final res = await ApiService.get(ApiConfig.elderlyStats);
    return res['data']['stats'] as Map<String, dynamic>;
  }
}
