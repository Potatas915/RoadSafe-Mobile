import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_mobile/backend/account_screen.dart';
import 'package:roadsafe_mobile/backend/backend.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistrationBackend extends RoadSafeBackend {
  String? requestedType;
  bool signedOut = false;
  @override
  bool get ready => true;
  @override
  Future<bool> signUp(
    String username,
    String password, {
    String accountType = 'Public',
  }) async {
    requestedType = accountType;
    return true;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  testWidgets(
    'enforcer login requires a cached station and activates duty only after access check',
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
            if (rpc == 'get_login_stations') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 'way/2',
                    'name': 'Cached Station',
                    'address': 'Fixture town',
                  },
                ]),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            if (rpc == 'set_enforcer_duty') {
              expect(jsonDecode(request.body), {
                'p_station': 'way/2',
                'p_on_duty': true,
              });
            }
            return http.Response(
              '{}',
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        ),
      ))!;
      final backend = LoginBackend(client: client);
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(home: AccountScreen(backend: backend, enforcer: true)),
      );
      await tester.pumpAndSettle();
      expect(calls, ['get_login_stations']);
      expect(
        find.text('Could not load stations. Retry before signing in.'),
        findsNothing,
      );
      expect(
        find.text('Cached Station — Fixture town', skipOffstage: false),
        findsWidgets,
      );
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
      expect(backend.logins, 0);
      expect(find.text('Choose your stationed location'), findsOneWidget);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cached Station — Fixture town').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(backend.logins, 1);
      expect(calls, [
        'get_login_stations',
        'get_enforcer_context',
        'set_enforcer_duty',
      ]);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'registration has its own route and enforcer choice awaits Admin approval',
    (tester) async {
      final backend = RegistrationBackend();
      await tester.pumpWidget(
        MaterialApp(home: AccountScreen(backend: backend)),
      );
      expect(find.text('Account type'), findsNothing);
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('account-type-Officer')));
      await tester.tap(find.byKey(const Key('account-type-Officer')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'fixture_officer',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'fixture_password',
      );
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(backend.requestedType, 'Officer');
      expect(backend.signedOut, true);
      expect(find.textContaining('An Admin must verify'), findsOneWidget);
    },
  );
}

class LoginBackend extends RoadSafeBackend {
  LoginBackend({super.client});
  int logins = 0;
  @override
  Future<void> signIn(String username, String password) async {
    logins++;
  }
}
