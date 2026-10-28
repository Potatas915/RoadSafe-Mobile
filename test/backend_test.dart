import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roadsafe_mobile/backend/backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final savedContact in ['', '09171234567']) {
    test(
      'reporter profile reuses saved contact or persists a marked test placeholder: $savedContact',
      () async {
        const uid = '11111111-1111-4111-8111-111111111111';
        var metadata = <String, dynamic>{'mobile_number': savedContact};
        var writes = 0;
        Map<String, dynamic> user() => {
          'id': uid,
          'aud': 'authenticated',
          'email': 'fixture@example.test',
          'created_at': '2026-10-17T00:00:00Z',
          'app_metadata': {},
          'user_metadata': metadata,
        };
        final payload = base64Url
            .encode(
              utf8.encode(
                jsonEncode({
                  'sub': uid,
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
        final client = SupabaseClient(
          'https://fixture.supabase.co',
          'fixture',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            Object response;
            if (request.url.path.endsWith('/token')) {
              response = {
                'access_token': token,
                'refresh_token': 'refresh',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': user(),
              };
            } else if (request.url.path == '/auth/v1/user') {
              if (request.method == 'PUT') {
                metadata = Map<String, dynamic>.from(
                  (jsonDecode(request.body) as Map)['data'] as Map,
                );
                writes++;
              }
              response = user();
            } else {
              expect(request.url.path, '/rest/v1/profiles');
              expect(request.url.queryParameters['id'], 'eq.$uid');
              response = {'name': 'Fixture Reporter'};
            }
            return http.Response(
              jsonEncode(response),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final backend = RoadSafeBackend(client: client);
        await backend.signIn('fixture@example.test', 'fixture-password');
        final profile = await backend.reporterProfile();
        expect(profile, {
          'name': 'Fixture Reporter',
          'contact': savedContact.isEmpty ? '09000000000' : savedContact,
        });
        expect(writes, savedContact.isEmpty ? 1 : 0);
        if (savedContact.isEmpty) {
          expect(metadata['mobile_number_is_test'], true);
        }
      },
    );
  }
  test(
    'Registration keeps profile name and contact email separate from username login',
    () async {
      Map<String, dynamic>? payload;
      final client = SupabaseClient(
        'https://fixture.supabase.co',
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/functions/v1/register-username');
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '{}',
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final backend = RegistrationCaptureBackend(client: client);
      addTearDown(client.dispose);
      expect(
        await backend.signUp(
          ' MARIA@EXAMPLE.COM ',
          'fixture-password',
          fullName: ' Maria   Santos ',
          mobileNumber: '09171234567',
          username: ' Maria_Officer ',
          accountType: 'Officer',
          stationId: 'way/2',
        ),
        isTrue,
      );
      expect(payload, {
        'email': 'maria@example.com',
        'fullName': 'Maria Santos',
        'mobileNumber': '09171234567',
        'username': 'maria_officer',
        'password': 'fixture-password',
        'accountType': 'Officer',
        'stationId': 'way/2',
      });
      expect(backend.loginEmail, 'maria_officer');
    },
  );
  test(
    'Structured submission preserves vehicle types and known casualty counts',
    () {
      final params = buildSubmissionParams(
        submissionId: 'structured-id',
        category: 'collision',
        description: 'Observed crash',
        latitude: 14.85,
        longitude: 120.88,
        occurredAt: DateTime.utc(2026, 10, 19),
        injuries: 'fatal',
        vehicleStatus: 'known',
        vehicles: [
          {'type': 'car', 'count': 2},
          {'type': 'motorcycle', 'count': 1},
        ],
        injuredCount: 3,
        fatalityCount: 1,
      );
      expect(params['p_vehicles'], [
        {'type': 'car', 'count': 2},
        {'type': 'motorcycle', 'count': 1},
      ]);
      expect(params['p_vehicle_status'], 'known');
      expect(params['p_injured_count'], 3);
      expect(params['p_fatality_count'], 1);
    },
  );
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
      expect(params['p_vehicle_status'], 'unknown');
      expect(params['p_vehicles'], isEmpty);
      expect(params['p_injured_count'], isNull);
      expect(params['p_fatality_count'], isNull);
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

class RegistrationCaptureBackend extends RoadSafeBackend {
  @override
  Future<void> saveMobileNumber(String mobileNumber) async {
    expect(mobileNumber, '09171234567');
  }

  RegistrationCaptureBackend({super.client});
  String? loginEmail;
  @override
  Future<void> signIn(String username, String password) async {
    loginEmail = username;
  }
}
