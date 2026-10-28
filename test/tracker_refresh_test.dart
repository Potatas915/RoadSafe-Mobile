import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_mobile/backend/backend.dart';
import 'package:roadsafe_mobile/backend/report_tracking.dart';
import 'package:roadsafe_mobile/widgets/report_progress.dart';

class TrackerBackend extends RoadSafeBackend {
  String status = 'Submitted';
  int loads = 0;
  @override
  bool get ready => true;
  @override
  Future<List<Map<String, dynamic>>> reports({bool ownOnly = true}) async {
    loads++;
    return [{'id': 'report', 'status': status, 'occurredAt': '2026-10-28T00:00:00Z'}];
  }
  @override
  Future<List<Map<String, dynamic>>> notifications() async => [];
}

void main() {
  testWidgets('tracker polls Admin changes and refreshes immediately on resume', (tester) async {
    final backend = TrackerBackend();
    addTearDown(backend.dispose);
    await tester.pumpWidget(MaterialApp(home: ReportTrackingScreen(backend: backend)));
    await tester.pump();
    expect(tester.widget<ReportProgress>(find.byType(ReportProgress)).status, 'Submitted');
    backend.status = 'Assigned';
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(tester.widget<ReportProgress>(find.byType(ReportProgress)).status, 'Assigned');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    backend.status = 'Resolved / Closed';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.widget<ReportProgress>(find.byType(ReportProgress)).status, 'Resolved / Closed');
    await tester.pumpWidget(const SizedBox());
    final loads = backend.loads;
    await tester.pump(const Duration(seconds: 10));
    expect(backend.loads, loads);
  });
}
