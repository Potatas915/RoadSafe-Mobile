import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_mobile/widgets/report_progress.dart';

void main() {
  testWidgets('assigned and in-progress reports animate the same responding step', (tester) async {
    for (final status in ['Assigned', 'In Progress']) {
      await tester.pumpWidget(MaterialApp(home: ReportProgress(status: status)));
      expect(find.text('On scene'), findsNothing);
      expect(find.text('Responding'), findsOneWidget);
      expect(reportStage(status), 2);
      final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bar.value, isNull);
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('completed reports are static and reduced motion disables animation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReportProgress(status: 'Resolved / Closed')));
    expect(find.text('Complete'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(reportStage('Resolved / Closed'), 3);
    await tester.pumpWidget(const MaterialApp(home: MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: ReportProgress(status: 'Assigned'),
    )));
    expect(find.text('Responding'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
