import 'dart:convert';

import 'package:berdikari_mobile/data/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiClient', () {
    test('attaches bearer token and Accept header', () async {
      late http.Request captured;
      final client = ApiClient(
        tokenProvider: () async => 'token-123',
        baseUrl: 'https://api.test/api/v1',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'data': []}), 200);
        }),
      );

      await client.get('/finance');

      expect(captured.url.toString(), 'https://api.test/api/v1/finance');
      expect(captured.headers['Authorization'], 'Bearer token-123');
      expect(captured.headers['Accept'], 'application/json');
    });

    test('omits Authorization header when no token stored', () async {
      late http.Request captured;
      final client = ApiClient(
        tokenProvider: () async => null,
        baseUrl: 'https://api.test/api/v1',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
      );

      await client.get('/auth/login');

      expect(captured.headers.containsKey('Authorization'), isFalse);
    });

    test('maps Laravel 422 validation bag to fieldErrors', () async {
      final client = ApiClient(
        tokenProvider: () async => null,
        baseUrl: 'https://api.test/api/v1',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'message': 'Data tidak valid.',
              'errors': {
                'email': ['Email wajib diisi.'],
                'password': ['Kata sandi minimal 8 karakter.'],
              },
            }),
            422,
          );
        }),
      );

      try {
        await client.post('/auth/login', body: {});
        fail('should have thrown');
      } on ApiException catch (e) {
        expect(e.isValidationError, isTrue);
        expect(e.message, 'Data tidak valid.');
        expect(e.fieldErrors['email'], 'Email wajib diisi.');
        expect(e.fieldErrors['password'], 'Kata sandi minimal 8 karakter.');
      }
    });

    test('invokes onUnauthorized on 401', () async {
      var unauthorizedCalled = false;
      final client = ApiClient(
        tokenProvider: () async => 'expired',
        baseUrl: 'https://api.test/api/v1',
        onUnauthorized: () async => unauthorizedCalled = true,
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode({'message': 'Unauthenticated.'}), 401);
        }),
      );

      await expectLater(
        client.get('/auth/me'),
        throwsA(
          isA<ApiException>().having((e) => e.isUnauthorized, 'unauthorized', true),
        ),
      );
      expect(unauthorizedCalled, isTrue);
    });

    test('falls back to Bahasa Indonesia message on non-JSON body', () async {
      final client = ApiClient(
        tokenProvider: () async => null,
        baseUrl: 'https://api.test/api/v1',
        httpClient: MockClient((request) async {
          return http.Response('<html>Bad Gateway</html>', 502);
        }),
      );

      await expectLater(
        client.get('/finance'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 502)
              .having((e) => e.message, 'message',
                  'Terjadi kesalahan. Silakan coba lagi.'),
        ),
      );
    });
  });
}
