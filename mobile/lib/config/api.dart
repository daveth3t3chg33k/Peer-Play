import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const _storage = FlutterSecureStorage();
  static const String _devBaseUrl = 'http://10.0.2.2:8080'; // Emulator localhost
  static const String _prodBaseUrl = 'https://api.peerplay.app';
  static const String _apiPrefix = '/api/v1';
  static final _client = http.Client();
  static const Duration _timeout = Duration(seconds: 30);

  static String get _baseUrl => _devBaseUrl;

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
