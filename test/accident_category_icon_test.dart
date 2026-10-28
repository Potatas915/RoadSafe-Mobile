import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:roadsafe_mobile/backend/backend.dart';
import 'package:roadsafe_mobile/backend/report_tracking.dart';
import 'package:roadsafe_mobile/widgets/accident_category_icon.dart';

class _ReportsBackend extends RoadSafeBackend {
  String? categoryId;
  @override
  bool get ready => true;
  @override
  Future<List<Map<String, dynamic>>> reports({bool ownOnly = true}) async => [
    {'id': 'report', 'status': 'Submitted', 'categoryId': categoryId},
  ];
  @override
  Future<List<Map<String, dynamic>>> notifications() async => [];
}

void main() {
  testWidgets('My reports chooses the website artwork for each category', (
    tester,
  ) async {
    for (final category in [
      'collision',
      'hit-and-run',
      'rollover',
      'pedestrian',
      'other',
      'unknown',
    ]) {
      final backend = _ReportsBackend()..categoryId = category;
      await tester.pumpWidget(
        MaterialApp(home: ReportTrackingScreen(backend: backend)),
      );
      await tester.pumpAndSettle();
      final icon = find.descendant(
        of: find.byType(AccidentCategoryIcon),
        matching: find.byType(SvgPicture),
      );
      final loader =
          tester.widget<SvgPicture>(icon).bytesLoader as SvgAssetLoader;
      expect(
        loader.assetName,
        'assets/images/accidents/${category == 'unknown' ? 'other' : category}.svg',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    }
  });
}
