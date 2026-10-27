import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_mobile/backend/account_screen.dart';
import 'package:roadsafe_mobile/backend/username.dart';

void main() {
  test(
    'Usernames normalize consistently and preserve existing login identities',
    () {
      expect(loginIdentity(' Admin '), 'admin@roadsafe.local');
      expect(loginIdentity('Driver_123'), 'driver_123@roadsafe.local');
      expect(loginIdentity(' Existing@Example.com '), 'existing@example.com');
      for (final value in ['ab', '1driver', 'name with spaces', 'a' * 25]) {
        expect(validUsername(value), isFalse);
        expect(() => loginIdentity(value), throwsFormatException);
      }
    },
  );

  testWidgets('Registration asks for full name, username, email and password', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AccountScreen(registration: true)),
    );
    await tester.pump();
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('Middle name'), findsOneWidget);
    expect(find.text('Last name'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(6));
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.textContaining('confirm your account'), findsNothing);
  });
}
