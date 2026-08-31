import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api.dart';
import '../models/movie.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  static Future<AuthResponse> register(String email, String password, String displayName) async {
    final fingerprint = await _getDeviceFingerprint();
    final response = await ApiClient.post('/auth/register', body: {
      'email': email,
      'password': password,
      'display_name': displayName,
      'device_fingerprint': fingerprint,
    });
    final data = AuthResponse.fromJson(jsonDecode(response.body));
    await _storage.write(key: 'auth_token', value: data.token);
    await _storage.write(key: 'user', value: jsonEncode({
      'id': data.user.id,
      'email': data.user.email,
      'display_name': data.user.displayName,
      'created_at': data.user.createdAt,
    }));
    return data;
  }

  static Future<AuthResponse> login(String email, String password) async {
    final fingerprint = await _getDeviceFingerprint();
    final response = await ApiClient.post('/auth/login', body: {
      'email': email,
      'password': password,
      'device_fingerprint': fingerprint,
    });
    final data = AuthResponse.fromJson(jsonDecode(response.body));
    await _storage.write(key: 'auth_token', value: data.token);
    await _storage.write(key: 'user', value: jsonEncode({
      'id': data.user.id,
      'email': data.user.email,
      'display_name': data.user.displayName,
      'created_at': data.user.createdAt,
    }));
    return data;
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user');
  }

  static Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null && token.isNotEmpty;
  }

  /// Get the currently stored user profile (from secure storage).
  static Future<User?> getCurrentUser() async {
    final userJson = await _storage.read(key: 'user');
    if (userJson == null) return null;
    try {
      return User.fromJson(jsonDecode(userJson));
    } catch (_) {
      return null;
    }
  }

  /// Get the stored JWT token (for API calls that need it).
  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<String> _getDeviceFingerprint() async {
    var fingerprint = await _storage.read(key: 'device_fingerprint');
    if (fingerprint != null) return fingerprint;
    final chars = 'abcdef0123456789';
    final random = List.generate(64, (_) => chars.codeUnitAt(0) + (DateTime.now().microsecond % 16));
    fingerprint = String.fromCharCodes(random);
    await _storage.write(key: 'device_fingerprint', value: fingerprint);
    return fingerprint;
  }
}
