import 'dart:convert';

import 'package:berdikari_mobile/data/services/api_client.dart';
import 'package:berdikari_mobile/data/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Contract tests against the IAM envelope `{success, data, message}` —
/// shapes taken from berdikari-web `app/stores/auth.ts`.
void main() {
  AuthService serviceReturning(Map<String, dynamic> payload) => AuthService(
        apiClient: ApiClient(
          tokenProvider: () async => null,
          baseUrl: 'https://api.test/api/v1',
          httpClient:
              MockClient((request) async => http.Response(
                    jsonEncode(payload),
                    200,
                    headers: {'content-type': 'application/json'},
                  )),
        ),
      );

  const userJson = {
    'id': 7,
    'name': 'Ibu Sari',
    'email': 'sari@berdikari.id',
    'role': 'cashier',
    'business_id': 3,
    'roles': ['cashier'],
    'permissions': ['pos.view', 'pos.open'],
  };

  test('login parses token + user from the data envelope', () async {
    final service = serviceReturning({
      'success': true,
      'data': {'token': 'sanctum-token', 'user': userJson},
      'message': 'Berhasil masuk.',
    });

    final session =
        await service.login(email: 'sari@berdikari.id', password: 'rahasia');

    expect(session.token, 'sanctum-token');
    expect(session.user.id, '7');
    expect(session.user.businessId, '3');
    expect(session.user.permissions, contains('pos.open'));
  });

  test('me parses the user from the data envelope', () async {
    final service = serviceReturning({'success': true, 'data': userJson});

    final user = await service.me();

    expect(user.name, 'Ibu Sari');
    expect(user.roles, ['cashier']);
  });
}
