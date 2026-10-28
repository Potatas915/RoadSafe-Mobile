import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:roadsafe_mobile/screens/report_screen.dart';
import 'package:roadsafe_mobile/backend/backend.dart';

class ProfileBackend extends RoadSafeBackend {
  @override
  bool get signedIn => true;
  @override
  String get userId => 'resident';
  @override
  Future<Map<String, String>> reporterProfile() async => {
    'name': 'Fixture Reporter',
    'contact': '09171234567',
  };
}

void main() {
  testWidgets(
    'Reports reuse profile identity and only require confirmed location',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReportScreen(
            backend: ProfileBackend(),
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
      expect(find.byKey(const Key('reporter-name')), findsNothing);
      expect(find.byKey(const Key('reporter-contact')), findsNothing);
      expect(find.text('Check your report'), findsOneWidget);
      expect(find.text('Fixture Reporter'), findsOneWidget);
      expect(find.text('09171234567'), findsOneWidget);
    },
  );
}
