import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_mobile/backend/backend.dart';
import 'package:roadsafe_mobile/backend/enforcer.dart';
import 'package:roadsafe_mobile/screens/enforcer_screen.dart';

class FixtureBackend extends RoadSafeBackend {
  @override
  String get userId => 'officer';
  @override
  Future<List<Map<String, dynamic>>> reports({bool ownOnly = true}) async => [
    {
      'id': 'case-1',
      'version': 3,
      'categoryLabel': 'Collision case',
      'status': 'Assigned',
      'assignedOfficerId': 'officer',
      'isDuplicate': false,
      'reporter': {'userId': 'public'},
      'location': {
        'address': 'Fictional street',
        'coordinates': {'latitude': 14.85, 'longitude': 120.88},
      },
      'description': 'Fictional collision for testing.',
      'officialRemarks': '',
      'verification': {'verifiedAt': '2026-10-20T00:00:00Z'},
      'occurredAt': '2026-10-20T00:00:00Z',
      'injuries': {'status': 'unknown'},
      'vehicles': [],
      'vehicleStatus': 'unknown',
      'evidence': [],
      'events': [],
    },
  ];
}

class FixtureApi extends EnforcerBackend {
  FixtureApi(super.backend);
  final writes = <Map<String, dynamic>>[];
  String? station;
  bool onDuty = false;
  @override
  Future<Map<String, dynamic>> context() async => {
    'name': 'Fixture Enforcer',
    'stationId': station,
    'onDuty': onDuty,
    'stations': [
      {'id': 'node/1', 'name': 'Station One', 'address': 'Fictional road'},
      {'id': 'way/2', 'name': 'Station Two', 'address': 'Fictional town'},
    ],
  };
  @override
  Future<void> duty(String nextStation, bool nextDuty) async {
    station = nextStation;
    onDuty = nextDuty;
    writes.add({
      'rpc': 'set_enforcer_duty',
      'p_station': station,
      'p_on_duty': onDuty,
    });
  }

  @override
  Future<void> update(
    Map<String, dynamic> report,
    String status,
    String remarks,
  ) async {
    writes.add({
      'rpc': 'update_accident_report',
      'p_version': report['version'],
      'p_officer': report['assignedOfficerId'],
      'p_status': status,
      'p_remarks': remarks,
    });
  }
}

void main() {
  testWidgets(
    'narrow phone selects a station, goes on duty and saves a versioned response',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backend = FixtureBackend();
      final service = FixtureApi(backend);
      final writes = service.writes;
      addTearDown(backend.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: EnforcerScreen(backend: backend, service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Fixture Enforcer'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .join('\n'),
      );
      await tester.tap(find.text('Select police station'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Two');
      await tester.pumpAndSettle();
      expect(find.text('Station One'), findsNothing);
      await tester.tap(find.text('Station Two'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        writes.any(
          (w) =>
              w['rpc'] == 'set_enforcer_duty' &&
              w['p_station'] == 'way/2' &&
              w['p_on_duty'] == true,
        ),
        isTrue,
      );
      await tester.ensureVisible(find.text('Collision case'));
      await tester.tap(find.text('Collision case'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In Progress · Responding / on scene').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'On scene. Findings: road obstruction. Actions: assisted safely.',
      );
      await tester.ensureVisible(find.text('Save response update'));
      await tester.tap(find.text('Save response update'));
      await tester.pumpAndSettle();
      final update = writes.singleWhere(
        (w) => w['rpc'] == 'update_accident_report',
      );
      expect(update['p_version'], 3);
      expect(update['p_officer'], 'officer');
      expect(update['p_status'], 'In Progress');
      expect(update['p_remarks'], contains('Actions: assisted safely.'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
