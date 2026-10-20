import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:roadsafe_mobile/screens/report_screen.dart';

void main() {
  testWidgets('New reports require name and contact before review', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReportScreen(
          locationPickerBuilder: (_, changed) => TextButton(
            onPressed: () => changed(const LatLng(14.85, 120.88)),
            child: const Text('Confirm test pin'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collision'));
    await tester.ensureVisible(find.byKey(const Key('description')));
    await tester.enterText(
      find.byKey(const Key('description')),
      'Observed crash',
    );
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm test pin'));
    await tester.ensureVisible(find.text('Review report'));
    await tester.tap(find.text('Review report'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter your contact number'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('reporter-name')));
    await tester.enterText(
      find.byKey(const Key('reporter-name')),
      ' Fixture Reporter ',
    );
    await tester.ensureVisible(find.byKey(const Key('reporter-contact')));
    await tester.enterText(
      find.byKey(const Key('reporter-contact')),
      '09000000000',
    );
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Review report'));
    await tester.tap(find.text('Review report'));
    await tester.pumpAndSettle();
    expect(find.text('Check your report'), findsOneWidget);
    expect(find.text('Fixture Reporter'), findsOneWidget);
    expect(find.text('09000000000'), findsOneWidget);
  });
}
