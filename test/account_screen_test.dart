import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_mobile/backend/account_screen.dart';
import 'package:roadsafe_mobile/backend/backend.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountBackend extends RoadSafeBackend {
  AccountBackend({super.client});
  String? requestedType;
  String? requestedStation;
  String? requestedName;
  String? requestedEmail;
  bool signedOut = false;
  int logins = 0;
  @override
  bool get ready => true;
  @override
  Future<void> signIn(String username, String password) async {
    logins++;
  }

  @override
  Future<bool> signUp(
    String username,
    String password, {
    required String fullName,
    String accountType = 'Public',
    String? stationId,
  }) async {
    requestedType = accountType;
    requestedName = fullName;
    requestedEmail = username;
    requestedStation = stationId;
    return true;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  for (final savedStation in ['way/2', null]) {
    testWidgets(
      'enforcer sign-in uses saved station $savedStation without a picker',
      (tester) async {
        final calls = <String>[];
        final client = (await tester.runAsync(
          () async => SupabaseClient(
            'https://fixture.supabase.co',
            'fixture',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
              final rpc = request.url.path.split('/').last;
              calls.add(rpc);
              if (rpc == 'set_enforcer_duty_checked') {
                expect(jsonDecode(request.body), {
                  'p_station': 'way/2',
                  'p_on_duty': true,
                  'p_expected_station_id': 'way/2',
                });
              }
              return http.Response(
                jsonEncode(
                  rpc == 'get_enforcer_context'
                      ? {'stationId': savedStation}
                      : {},
                ),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }),
          ),
        ))!;
        addTearDown(client.dispose);
        final backend = AccountBackend(client: client);
        await tester.pumpWidget(
          MaterialApp(home: AccountScreen(backend: backend, enforcer: true)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Station'), findsNothing);
        expect(calls, isEmpty);
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'fixture_officer',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'fixture_password',
        );
        await tester.ensureVisible(find.text('Sign in'));
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();
        expect(backend.logins, 1);
        expect(calls, [
          'get_enforcer_context',
          if (savedStation != null) 'set_enforcer_duty_checked',
        ]);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'enforcer signup searches nationwide directory and saves station while awaiting approval',
    (tester) async {
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'https://fixture.supabase.co',
          'fixture',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode([
                {
                  'id': 'node/1',
                  'name': 'Luzon Station',
                  'address': 'Malolos, Bulacan',
                },
                {
                  'id': 'way/2',
                  'name': 'Southern Station',
                  'address': 'Davao City, Mindanao',
                },
                {
                  'id': 'node/3',
                  'name': 'Visayas Station',
                  'address': 'Cebu City',
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            ),
          ),
        ),
      ))!;
      addTearDown(client.dispose);
      final backend = AccountBackend(client: client);
      await tester.pumpWidget(
        MaterialApp(home: AccountScreen(backend: backend)),
      );
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('account-type-Officer')));
      await tester.tap(find.byKey(const Key('account-type-Officer')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Maria Santos');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'maria@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'fixture_password',
      );
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(backend.requestedType, isNull);
      expect(find.text('Choose your stationed location'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('registration-station-picker')),
      );
      await tester.tap(find.byKey(const Key('registration-station-picker')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'no matching station',
      );
      await tester.pumpAndSettle();
      expect(find.text('No stations match your search.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '  DAVAO  ');
      await tester.pumpAndSettle();
      expect(find.text('Southern Station'), findsOneWidget);
      expect(find.text('Luzon Station'), findsNothing);
      await tester.enterText(find.byType(TextField).last, 'southern');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Southern Station'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(backend.requestedType, 'Officer');
      expect(backend.requestedStation, 'way/2');
      expect(backend.requestedName, 'Maria Santos');
      expect(backend.requestedEmail, 'maria@example.com');
      expect(backend.signedOut, true);
      expect(find.textContaining('An Admin must verify'), findsOneWidget);
    },
  );
}
