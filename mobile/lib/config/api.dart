import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const _storage = FlutterSecureStorage();
  static const String _apiPrefix = '/api/v1';

  /// Default backend for the test builds. Override at build time with
  /// `--dart-define=PEERPLAY_API_BASE_URL=http://host:8080`, or at runtime from
  /// Settings → Backend Server.
  static const String defaultBaseUrl = String.fromEnvironment(
    'PEERPLAY_API_BASE_URL',
    defaultValue: 'http://192.168.100.38:8080',
  );

  static const String _prefKey = 'api_base_url';
  static String _baseUrl = defaultBaseUrl;

  static final _client = http.Client();
  static const Duration _timeout = Duration(seconds: 30);

  static String get baseUrl => _baseUrl;

  /// Load the saved backend URL. Call once before `runApp`.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _baseUrl = normalizeBaseUrl(saved);
    }
  }

  /// Persist a new backend URL. Returns false when [value] is not a valid URL.
  static Future<bool> setBaseUrl(String value) async {
    final normalized = normalizeBaseUrl(value);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, normalized);
    _baseUrl = normalized;
    return true;
  }

  /// Normalises user input: trims, adds a scheme when missing, drops trailing
  /// slashes and an accidental `/api/v1` suffix.
  static String normalizeBaseUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return defaultBaseUrl;
    if (!value.contains('://')) value = 'http://$value';
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.endsWith(_apiPrefix)) {
      value = value.substring(0, value.length - _apiPrefix.length);
    }
    return value;
  }

  static Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Attach JWT + device fingerprint to every request
  static Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    final fingerprint = await _storage.read(key: 'device_fingerprint');
    final headers = Map<String, String>.from(_defaultHeaders);
    if (token != null) headers['Authorization'] = 'Bearer $token';
    if (fingerprint != null) headers['X-Device-Fingerprint'] = fingerprint;
    return headers;
  }

  static Future<http.Response> get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$_baseUrl$_apiPrefix$path').replace(queryParameters: queryParams);
    final headers = await _authHeaders();
    final response = await _client.get(uri, headers: headers).timeout(_timeout);
    return _handleResponse(response);
  }

  static Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_baseUrl$_apiPrefix$path');
    final headers = await _authHeaders();
    final response = await _client.post(uri, headers: headers, body: jsonEncode(body)).timeout(_timeout);
    return _handleResponse(response);
  }

  static Future<http.Response> delete(String path) async {
    final uri = Uri.parse('$_baseUrl$_apiPrefix$path');
    final headers = await _authHeaders();
    final response = await _client.delete(uri, headers: headers).timeout(_timeout);
    return _handleResponse(response);
  }

  static http.Response _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      // Only delete token on 401 if it's a user-specific endpoint (not movie browsing)
      // Movie browsing is now public, so 401 likely means token is expired for protected routes
      // Don't silently delete — let the caller decide what to do
    }
    return response;
  }
}
