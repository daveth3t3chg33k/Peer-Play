import 'package:flutter_test/flutter_test.dart';

import 'package:peerplay/config/api.dart';

void main() {
  group('ApiClient.normalizeBaseUrl', () {
    test('trims whitespace and trailing slashes', () {
      expect(
        ApiClient.normalizeBaseUrl('  http://192.168.1.20:8080/  '),
        'http://192.168.1.20:8080',
      );
    });

    test('adds a scheme when the user omits it', () {
      expect(
        ApiClient.normalizeBaseUrl('192.168.1.20:8080'),
        'http://192.168.1.20:8080',
      );
    });

    test('drops an accidental /api/v1 suffix', () {
      expect(
        ApiClient.normalizeBaseUrl('http://192.168.1.20:8080/api/v1'),
        'http://192.168.1.20:8080',
      );
      expect(
        ApiClient.normalizeBaseUrl('http://192.168.1.20:8080/api/v1/'),
        'http://192.168.1.20:8080',
      );
    });

    test('falls back to the default for empty input', () {
      expect(ApiClient.normalizeBaseUrl('   '), ApiClient.defaultBaseUrl);
    });
  });
}
