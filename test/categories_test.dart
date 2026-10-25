import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_mobile/backend/categories.dart';
import 'package:roadsafe_mobile/screens/report_screen.dart';

void main() {
  test(
    'Catalog retains historical IDs and disabled names; rejects malformed data',
    () {
      final rows = defaultCategories
          .map(
            (row) => <String, dynamic>{
              'id': row.id,
              'label': row.id == 'collision' ? 'Road collision' : row.label,
              'enabled': row.id != 'collision',
            },
          )
          .toList();
      final catalog = parseCategories(rows);
      expect(catalog.first.label, 'Road collision');
      expect(catalog.first.enabled, false);
      expect(catalog.first.id, 'collision');
      expect(
        () => parseCategories(rows.skip(1).toList()),
        throwsFormatException,
      );
      rows.first['enabled'] = 'false';
      expect(() => parseCategories(rows), throwsFormatException);
    },
  );

  testWidgets(
    'Form loads current labels, removes disabled choices, and refreshes stale selection',
    (tester) async {
      var disabled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ReportScreen(
            categoryLoader: () async => defaultCategories
                .map(
                  (row) => AccidentCategory(
                    row.id,
                    row.id == 'collision' ? 'Road collision' : row.label,
                    row.id != 'collision' || !disabled,
                  ),
                )
                .toList(),
            locationPickerBuilder: (_, _) => const Text('Test map'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Road collision'), findsOneWidget);
      await tester.tap(find.text('Road collision'));
      disabled = true;
      await tester.tap(find.byTooltip('Refresh categories'));
      await tester.pumpAndSettle();
      expect(find.text('Road collision'), findsNothing);
      expect(find.text('Other accident'), findsOneWidget);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Select an available accident type'), findsOneWidget);
    },
  );

  testWidgets('Category loading errors are visible and can be retried', (
    tester,
  ) async {
    var fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: ReportScreen(
          categoryLoader: () async {
            if (fail) throw Exception('offline');
            return defaultCategories;
          },
          locationPickerBuilder: (_, _) => const Text('Test map'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not load current categories'),
      findsOneWidget,
    );
    fail = false;
    await tester.tap(find.byTooltip('Refresh categories'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not load current categories'),
      findsNothing,
    );
    expect(find.text('Collision'), findsOneWidget);
  });
}
