import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_mobile/backend/account_screen.dart';

void main() {
  testWidgets('signup validates while editing and rejects whitespace passwords', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AccountScreen(registration: true)));
    final form = tester.widget<Form>(find.byType(Form));
    expect(form.autovalidateMode, AutovalidateMode.onUserInteraction);
    final password = tester.widget<TextFormField>(find.ancestor(of: find.widgetWithText(TextField, 'Password'), matching: find.byType(TextFormField)));
    expect(password.validator!('        '), isNotNull);
    expect(password.validator!('fixture_password'), isNull);
    final firstName = find.widgetWithText(TextField, 'First name');
    await tester.enterText(firstName, 'Maria123');
    await tester.pump();
    expect(find.text('Use letters only (no numbers or symbols)'), findsOneWidget);
    await tester.enterText(firstName, 'Maria');
    await tester.pump();
    expect(find.text('Use letters only (no numbers or symbols)'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('enforcer sign-in rejects usernames and internal login addresses', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AccountScreen(enforcer: true)));
    final field = tester.widget<TextFormField>(find.ancestor(of: find.widgetWithText(TextField, 'Email'), matching: find.byType(TextFormField)));
    expect(field.validator!('officer_name'), isNotNull);
    expect(field.validator!('officer_name@roadsafe.local'), isNotNull);
    expect(field.validator!('officer@example.com'), isNull);
    await tester.pumpWidget(const SizedBox());
  });}

// Enforcer identities use email while public accounts retain legacy compatibility.
