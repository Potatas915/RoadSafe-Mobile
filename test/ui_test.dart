import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_mobile/main.dart';
import 'package:roadsafe_mobile/screens/report_screen.dart';
import 'package:roadsafe_mobile/theme/roadsafe_theme.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

Future<void> enterDetails(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Collision'));
  await tester.tap(find.text('Collision'));
  await tester.ensureVisible(find.byKey(const Key('description')));
  await tester.enterText(
    find.byKey(const Key('description')),
    'Two cars collided near the crossing.',
  );
  await tester.ensureVisible(find.text('Continue'));
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

Future<void> pumpReportWithTestMap(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildRoadSafeTheme(),
      home: ReportScreen(
        locationPickerBuilder: (initial, changed) => Column(
          children: [
            if (initial != null)
              Text(
                '${initial.latitude.toStringAsFixed(6)}, ${initial.longitude.toStringAsFixed(6)}',
              ),
            TextButton(
              onPressed: () => changed(const LatLng(14.85, 120.88)),
              child: const Text('Confirm test pin'),
            ),
            TextButton(
              onPressed: () => changed(null),
              child: const Text('Move test pin'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> enterReporter(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('reporter-name')));
  await tester.enterText(
    find.byKey(const Key('reporter-name')),
    'Fixture Reporter',
  );
  await tester.ensureVisible(find.byKey(const Key('reporter-contact')));
  await tester.enterText(
    find.byKey(const Key('reporter-contact')),
    '09000000000',
  );
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/image_picker'),
          (call) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/image_picker'),
          null,
        );
  });
  testWidgets('Known injury counts reject zero and accept an unknown blank', (
    tester,
  ) async {
    await pumpReportWithTestMap(tester);
    await tester.tap(find.text('Collision'));
    await tester.ensureVisible(find.text('Someone is hurt'));
    await tester.tap(find.text('Someone is hurt'));
    await tester.pumpAndSettle();
    final count = find.widgetWithText(TextFormField, 'Known injured count');
    await tester.ensureVisible(count);
    await tester.enterText(count, '0');
    await tester.ensureVisible(find.byKey(const Key('description')));
    await tester.enterText(
      find.byKey(const Key('description')),
      'Observed crash',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a whole number from 1 to 999, or leave blank'),
      findsOneWidget,
    );
    await tester.ensureVisible(count);
    await tester.enterText(count, '');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm test pin'), findsOneWidget);
  });

  testWidgets(
    'Vehicle counts are required for known details and survive review',
    (tester) async {
      await pumpReportWithTestMap(tester);
      await tester.tap(find.text('Collision'));
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Known types and counts').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('description')));
      await tester.enterText(
        find.byKey(const Key('description')),
        'Observed crash',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('Add at least one vehicle type and count'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byTooltip('Add car'));
      await tester.tap(find.byTooltip('Add car'));
      await tester.tap(find.byTooltip('Add car'));
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirm test pin'));
      await tester.tap(find.text('Confirm test pin'));
      await enterReporter(tester);
      await tester.ensureVisible(find.text('Review report'));
      await tester.tap(find.text('Review report'));
      await tester.pumpAndSettle();
      expect(find.text('2 × car'), findsOneWidget);
    },
  );

  testWidgets('Home opens reporting and provides a way back', (tester) async {
    await tester.pumpWidget(const RoadSafeApp());
    expect(find.text('A little action.\nA safer community.'), findsOneWidget);
    expect(find.text('Report an Accident'), findsOneWidget);
    expect(find.text('Report an accident'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    await tester.ensureVisible(find.text('Report updates will appear here'));
    expect(find.text('Report updates will appear here'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('report-accident')));
    await tester.tap(find.byKey(const Key('report-accident')));
    await tester.pumpAndSettle();
    expect(find.text('Report an accident'), findsOneWidget);
    await tester.tap(find.byTooltip('Return home'));
    await tester.pumpAndSettle();
    expect(find.text('Report an Accident'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets('Public app only exposes accident reporting', (tester) async {
    await tester.pumpWidget(const RoadSafeApp());
    await tester.ensureVisible(find.byKey(const Key('report-accident')));
    await tester.tap(find.byKey(const Key('report-accident')));
    await tester.pumpAndSettle();
    expect(find.text('Report an accident'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('GIS Tactical Map'), findsNothing);
    expect(find.text('Police Stations'), findsNothing);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Select an accident type'), findsOneWidget);
    expect(find.text('Describe the accident'), findsOneWidget);
  });

  testWidgets(
    'Confirmed coordinates are required and retained during editing',
    (tester) async {
      await pumpReportWithTestMap(tester);
      await enterDetails(tester);
      await enterReporter(tester);
      await tester.ensureVisible(find.text('Review report'));
      await tester.tap(find.text('Review report'));
      await tester.pumpAndSettle();
      expect(
        find.text('Pin and confirm the accident location'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Confirm test pin'));
      await tester.tap(find.text('Confirm test pin'));
      await tester.pumpAndSettle();
      await enterReporter(tester);
      await tester.ensureVisible(find.text('Review report'));
      await tester.tap(find.text('Review report'));
      await tester.pumpAndSettle();
      expect(find.text('Check your report'), findsOneWidget);
      expect(find.text('14.850000, 120.880000'), findsOneWidget);
      expect(find.text('Two cars collided near the crossing.'), findsOneWidget);
      await tester.ensureVisible(find.text('Back'));
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('14.850000, 120.880000'), findsOneWidget);
      await tester.ensureVisible(find.text('Move test pin'));
      await tester.tap(find.text('Move test pin'));
      await tester.pumpAndSettle();
      await enterReporter(tester);
      await tester.ensureVisible(find.text('Review report'));
      await tester.tap(find.text('Review report'));
      await tester.pumpAndSettle();
      expect(
        find.text('Pin and confirm the accident location'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Back'));
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Two cars collided near the crossing.'), findsOneWidget);
    },
  );

  testWidgets('Reporting flow fits a narrow phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpReportWithTestMap(tester);
    expect(tester.takeException(), isNull);
    await enterDetails(tester);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Confirm test pin'));
    await tester.tap(find.text('Confirm test pin'));
    await tester.pumpAndSettle();
    await enterReporter(tester);
    await tester.ensureVisible(find.text('Review report'));
    await tester.tap(find.text('Review report'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
