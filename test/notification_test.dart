import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_mobile/backend/backend.dart';
import 'package:roadsafe_mobile/backend/report_tracking.dart';

class NotificationBackend extends RoadSafeBackend {
  bool read = false;
  bool fail = false;
  final changes = <bool>[];
  @override
  bool get ready => true;
  @override
  Future<List<Map<String, dynamic>>> reports({bool ownOnly = true}) async => [];
  @override
  Future<List<Map<String, dynamic>>> notifications() async => [
    {'id': 1, 'message': 'Your report was verified.', 'created_at': DateTime.now().toUtc().toIso8601String(), 'read_at': read ? '2026-10-28T00:00:00Z' : null},
  ];
  @override
  Future<void> setNotificationRead(int id, bool value) async {
    expect(id, 1);
    changes.add(value);
    if (fail) throw StateError('offline');
    read = value;
  }
}

void main() {
  testWidgets('notification action persists read and unread and preserves state on failure', (tester) async {
    final backend = NotificationBackend();
    addTearDown(backend.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: ReportTrackingScreen(backend: backend)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Updates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as unread'), findsOneWidget);
    await tester.tap(find.text('Mark as unread'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as read'), findsOneWidget);
    expect(backend.changes, [true, false]);
    backend.fail = true;
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as read'), findsOneWidget);
    expect(find.textContaining('Could not mark'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
