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
  String? requestedUsername;
  bool signedOut = false;
  int logins = 0;
  int registrations = 0;
  @override
  bool get ready => true;
  @override
  Future<void> signIn(String username, String password) async {
    logins++;
  }

  @override
  Future<bool> signUp(
    String email,
    String password, {
    required String fullName,
    String mobileNumber = '',
    String? username,
    String accountType = 'Public',
    String? stationId,
  }) async {
    registrations++;
    requestedType = accountType;
    requestedName = fullName;
    requestedEmail = email;
    requestedUsername = username;
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
          'fixture-officer@example.com',
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
  for (final middleName in ['', 'Reyes']) {
  testWidgets(
    'enforcer signup saves name parts with middle name "$middleName" and station while awaiting approval',
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
      expect(find.text('Username'), findsNothing);
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your first name'), findsOneWidget);
      expect(find.text('Enter your last name'), findsOneWidget);
      expect(backend.registrations, 0);
      await tester.enterText(find.byType(TextFormField).at(0), ' Maria ');
      await tester.enterText(find.byType(TextFormField).at(1), middleName);
      await tester.enterText(find.byType(TextFormField).at(2), ' Santos ');
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'maria@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(4),
        'fixture_password',
      );
      await tester.ensureVisible(find.byKey(const Key('registration-mobile')));
      await tester.enterText(find.byKey(const Key('registration-mobile')), '09171234567');
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
      expect(backend.requestedName, middleName.isEmpty ? 'Maria Santos' : 'Maria Reyes Santos');
      expect(backend.requestedEmail, 'maria@example.com');
      expect(backend.requestedUsername, isNull);
      expect(backend.signedOut, true);
      expect(find.textContaining('An Admin must verify'), findsOneWidget);
      expect(find.text('Create account'), findsNothing);
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Enforcer sign in'), findsOneWidget);
      expect(backend.registrations, 1);
      expect(find.byKey(const Key('registration-station-picker')), findsNothing);
    },
  );
  }
}
