import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roadsafe_mobile/backend/backend.dart';

void main() {
  for (final mode in [
    'username',
    'native-email',
    'contact-email',
    'wrong-password',
    'rate-limit',
  ]) {
    test('Resident login preserves $mode behavior', () async {
      var aliasCalls = 0;
      const uid = '11111111-1111-4111-8111-111111111111';
      final token =
          'eyJhbGciOiJIUzI1NiJ9.${base64Url.encode(utf8.encode(jsonEncode({'sub': uid, 'aud': 'authenticated', 'role': 'authenticated', 'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000}))).replaceAll('=', '')}.signature';
      final client = SupabaseClient(
        'https://fixture.supabase.co',
        'fixture-public',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (request.url.path == '/functions/v1/sign-in-resident') {
            aliasCalls++;
            expect(body, {
              'email': 'resident@example.test',
              'password': 'fixture-password',
            });
            return http.Response(
              jsonEncode(
                mode == 'wrong-password'
                    ? {
                        'message':
                            'Invalid email or password. Try your username if this email is shared.',
                      }
                    : {'refresh_token': 'fixture-refresh'},
              ),
              mode == 'wrong-password' ? 401 : 200,
              headers: {'content-type': 'application/json'},
            );
          }
          expect(request.url.path, '/auth/v1/token');
          if (request.url.queryParameters['grant_type'] == 'password') {
            expect(
              body['email'],
              mode == 'username'
                  ? 'resident@roadsafe.local'
                  : 'resident@example.test',
            );
            if ([
              'contact-email',
              'wrong-password',
              'rate-limit',
            ].contains(mode)) {
              return http.Response(
                jsonEncode({
                  'error_code': mode == 'rate-limit'
                      ? 'over_request_rate_limit'
                      : 'invalid_credentials',
                  'msg': 'Invalid login credentials',
                }),
                mode == 'rate-limit' ? 429 : 400,
                headers: {'content-type': 'application/json'},
              );
            }
          } else {
            expect(request.url.queryParameters['grant_type'], 'refresh_token');
            expect(body['refresh_token'], 'fixture-refresh');
          }
          return http.Response(
            jsonEncode({
              'access_token': token,
              'refresh_token': 'fixture-refresh-rotated',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': uid,
                'aud': 'authenticated',
                'email': 'resident@roadsafe.local',
                'created_at': '2026-10-28T00:00:00Z',
                'app_metadata': {},
                'user_metadata': {},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final backend = RoadSafeBackend(client: client);
      final attempt = backend.signInResident(
        mode == 'username' ? ' Resident ' : ' RESIDENT@EXAMPLE.TEST ',
        'fixture-password',
      );
      if (['wrong-password', 'rate-limit'].contains(mode)) {
        await expectLater(attempt, throwsA(isA<AuthException>()));
        expect(client.auth.currentSession, isNull);
      } else {
        await attempt;
        expect(client.auth.currentUser?.id, uid);
      }
      expect(
        aliasCalls,
        ['contact-email', 'wrong-password'].contains(mode) ? 1 : 0,
      );
    });
  }
}
