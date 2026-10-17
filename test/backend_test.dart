import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roadsafe_mobile/backend/backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Submission uses confirmed coordinates, UTC incident time and unknown counts without trusting client roles',
    () {
      final params = buildSubmissionParams(
        submissionId: 'retry-id',
        category: 'collision',
        description: ' Two vehicles ',
        latitude: 14.85,
        longitude: 120.88,
        occurredAt: DateTime.utc(2026, 10, 17, 6),
        injuries: 'injured',
        name: ' Reporter ',
        contact: ' ',
      );
      expect(params['p_latitude'], 14.85);
      expect(params['p_longitude'], 120.88);
      expect(params['p_occurred_at'], '2026-10-17T06:00:00.000Z');
      expect(params['p_contact'], isNull);
      expect(params.containsKey('status'), isFalse);
      expect(params.containsKey('reporter_id'), isFalse);
      expect(params.containsKey('verified_by'), isFalse);
    },
  );

  test('Signed-out report submission never sends a request', () async {
    final httpClient = MockClient(
      (_) async => throw StateError('Unexpected request'),
    );
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      httpClient: httpClient,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final backend = RoadSafeBackend(client: client);
    addTearDown(() async {
      backend.dispose();
      await client.dispose();
    });
    await expectLater(backend.submit({}), throwsStateError);
  });

  test(
    'Account session is used for submit RPC and the same retry reference is preserved',
    () async {
      const uid = '11111111-1111-4111-8111-111111111111';
      final payload = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'sub': uid,
                'aud': 'authenticated',
                'role': 'authenticated',
                'exp':
                    DateTime.now()
                        .add(const Duration(hours: 1))
                        .millisecondsSinceEpoch ~/
                    1000,
              }),
            ),
          )
          .replaceAll('=', '');
      final token = 'eyJhbGciOiJIUzI1NiJ9.$payload.signature';
      final calls = <Map<String, dynamic>>[];
      final httpClient = MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            jsonEncode({
              'access_token': token,
              'refresh_token': 'refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': uid,
                'aud': 'authenticated',
                'email': 'reporter@example.test',
                'created_at': '2026-10-17T00:00:00Z',
                'app_metadata': {},
                'user_metadata': {},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        expect(request.url.path, '/rest/v1/rpc/submit_accident_report');
        expect(
          request.headers['Authorization'] ?? request.headers['authorization'],
          'Bearer $token',
        );
        calls.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
        return http.Response(
          jsonEncode('22222222-2222-4222-8222-222222222222'),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        httpClient: httpClient,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final backend = RoadSafeBackend(client: client);
      addTearDown(() async {
        backend.dispose();
        await client.dispose();
      });
      await backend.signIn('reporter@example.test', 'test-password');
      final draft = SubmissionDraft();
      final params = buildSubmissionParams(
        submissionId: draft.id,
        category: 'collision',
        description: 'Observed collision',
        latitude: 14.85,
        longitude: 120.88,
        occurredAt: DateTime.now(),
        injuries: 'unknown',
      );
      final first = await backend.submit(params);
      final retry = await backend.submit(params);
      expect(first, retry);
      expect(calls[0]['p_submission_id'], calls[1]['p_submission_id']);
    },
  );
}
