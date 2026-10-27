import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_mobile/backend/backend.dart';
import 'package:roadsafe_mobile/backend/enforcer.dart';
import 'package:roadsafe_mobile/screens/enforcer_screen.dart';

const fixtureReportId = 'c12e363d-c13c-43b3-870c-399b7ecadf1a';

class FixtureBackend extends RoadSafeBackend {
  int version = 3;
  String status = 'Assigned';
  bool signedOut = false;
  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  String get userId => 'officer';
  @override
  Future<List<Map<String, dynamic>>> reports({bool ownOnly = true}) async => [
    {
      'id': fixtureReportId,
      'version': version,
      'categoryLabel': 'Collision case',
      'status': status,
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
  int heartbeats = 0;
  bool transferBeforeWrite = false;
  @override
  Future<void> heartbeat() async {
    heartbeats++;
  }

  @override
  Future<Map<String, dynamic>?> medicalRecommendation(String reportId) async =>
      {
        'selectedId': 'node/9',
        'facilities': [
          {
            'id': 'node/9',
            'name': 'Fixture Hospital',
            'kind': 'Hospital',
            'address': 'Fictional health road',
            'lat': 14.851,
            'lng': 120.881,
            'distanceKm': 0.2,
          },
        ],
      };
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
  Future<void> duty(
    String nextStation,
    bool nextDuty, {
    required String? expectedStationId,
  }) async {
    if (transferBeforeWrite) {
      station = 'way/2';
      onDuty = false;
    }
    if (expectedStationId != station) throw StateError('Stale station');
    station = nextStation;
    onDuty = nextDuty;
    writes.add({
      'rpc': 'set_enforcer_duty_checked',
      'p_expected_station_id': expectedStationId,
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
    (backend as FixtureBackend).status = status;
    (backend as FixtureBackend).version++;
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
  testWidgets('mobile enforcer only sees assigned active cases and has no Verify tab', (tester) async {
    final backend = AssignedOnlyFixture();
    addTearDown(backend.dispose);
    await tester.pumpWidget(MaterialApp(home: EnforcerScreen(backend: backend, service: FixtureApi(backend))));
    await tester.pumpAndSettle();
    expect(find.text('Verify'), findsNothing);
    expect(find.text('My cases'), findsOneWidget);
    expect(find.text('Collision case'), findsOneWidget);
    expect(find.text('Unassigned accident'), findsNothing);
    expect(find.text('Other officer accident'), findsNothing);
    expect(find.text('Closed accident'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('case list preserves the full report UUID and its casing', (
    tester,
  ) async {
    final backend = FixtureBackend();
    final service = FixtureApi(backend);
    addTearDown(backend.dispose);
    await tester.pumpWidget(
      MaterialApp(home: EnforcerScreen(backend: backend, service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(fixtureReportId), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'sign out cannot restore a station transferred before its off duty write',
    (tester) async {
      final backend = FixtureBackend();
      final service = FixtureApi(backend)
        ..station = 'node/1'
        ..onDuty = true
        ..transferBeforeWrite = true;
      addTearDown(backend.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: EnforcerScreen(backend: backend, service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();
      expect(backend.signedOut, isTrue);
      expect(service.station, 'way/2');
      expect(service.onDuty, isFalse);
      expect(service.writes, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'refresh keeps an admin transfer off duty without replaying writes',
    (tester) async {
      final backend = FixtureBackend();
      final service = FixtureApi(backend)
        ..station = 'node/1'
        ..onDuty = true;
      addTearDown(backend.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: EnforcerScreen(backend: backend, service: service),
        ),
      );
      await tester.pumpAndSettle();
      service.station = 'way/2';
      service.onDuty = false;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('Station Two'), findsWidgets);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(service.writes, isEmpty);
      expect(service.heartbeats, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'a transfer racing duty activation refreshes server state without retry',
    (tester) async {
      final backend = FixtureBackend();
      final service = FixtureApi(backend)
        ..station = 'node/1'
        ..transferBeforeWrite = true;
      addTearDown(backend.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: EnforcerScreen(backend: backend, service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Station Two'), findsWidgets);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(service.station, 'way/2');
      expect(service.writes, isEmpty);
      expect(find.textContaining('Could not save duty'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
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
              w['rpc'] == 'set_enforcer_duty_checked' &&
              w['p_station'] == 'way/2' &&
              w['p_on_duty'] == true,
        ),
        isTrue,
      );
      await tester.ensureVisible(find.text('Collision case'));
      await tester.tap(find.text('Collision case'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Nearby hospitals & clinics'), 150, scrollable: find.byType(Scrollable).first);
      expect(find.text('Fixture Hospital · Recommended'), findsOneWidget);
      expect(
        find.text('Hospital · 0.2 km straight-line distance'),
        findsOneWidget,
      );
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      await tester.scrollUntilVisible(find.byType(TextField), 200, scrollable: find.byType(Scrollable).first);
      await tester.enterText(
        find.byType(TextField),
        'On scene. Findings: road obstruction. Actions: assisted safely.',
      );
      backend.version = 5;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Complete'));
      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();
      final updates = writes.where(
        (w) => w['rpc'] == 'update_accident_report',
      ).toList();
      expect(updates.map((w) => w['p_status']), ['In Progress', 'Resolved / Closed']);
      final update = updates.last;
      expect(update['p_version'], 6);
      expect(update['p_officer'], 'officer');
      expect(update['p_status'], 'Resolved / Closed');
      expect(update['p_remarks'], contains('Actions: assisted safely.'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class AssignedOnlyFixture extends FixtureBackend {
  @override
  Future<List<Map<String, dynamic>>> reports({bool ownOnly = true}) async {
    final own = (await super.reports()).single;
    return [own,
      {...own, 'id': 'unassigned', 'categoryLabel': 'Unassigned accident', 'status': 'Submitted', 'assignedOfficerId': null},
      {...own, 'id': 'other', 'categoryLabel': 'Other officer accident', 'assignedOfficerId': 'someone-else'},
      {...own, 'id': 'closed', 'categoryLabel': 'Closed accident', 'status': 'Resolved / Closed'},
    ];
  }
}
