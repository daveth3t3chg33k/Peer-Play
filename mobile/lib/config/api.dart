import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const _storage = FlutterSecureStorage();
  static const String _devBaseUrl = 'http://10.0.2.2:8080'; // Emulator localhost
  static const String _prodBaseUrl = 'https://api.peerplay.app';
  static const String _apiPrefix = '/api/v1';

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
    final response = await http.get(uri, headers: headers);
    return _handleResponse(response);
  }

  static Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_baseUrl$_apiPrefix$path');
    final headers = await _authHeaders();
    final response = await http.post(uri, headers: headers, body: jsonEncode(body));
    return _handleResponse(response);
  }

  static http.Response _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      _storage.delete(key: 'auth_token');
    }
    return response;
  }
}
