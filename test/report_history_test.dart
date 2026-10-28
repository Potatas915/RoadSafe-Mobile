import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_mobile/backend/format.dart';

void main() {
  test('assignment does not repeat earlier cancellation messages', () {
    final message = reportEventMessage({
      'type': 'assignment_changed', 'status': 'Assigned',
      'message': 'received\nPolice station request cancelled; officer unassigned.',
    });
    expect(message, startsWith('An enforcer was assigned to this report.'));
    expect(message, contains('received'));
    expect(message, isNot(contains('officer unassigned')));
  });
  test('response and closure omit stale cancellation lines but retain findings', () {
    for (final status in ['In Progress', 'Resolved / Closed']) {
      final event = {'type': 'review_updated', 'status': status,
        'message': 'Police station request cancelled; officer unassigned.\nRoad cleared.\nPolice station request cancelled; officer unassigned.'};
      final before = Map.of(event);
      final message = reportEventMessage(event);
      expect(message, contains('Road cleared.'));
      expect(message, isNot(contains('officer unassigned')));
      expect(event, before);
    }
  });
  test('empty assignment remarks and other event messages remain accurate', () {
    expect(reportEventMessage({'type': 'assignment_changed', 'status': 'Verified',
      'message': 'Police station request cancelled; officer unassigned.'}),
      'Police station request cancelled; officer unassigned.');
    expect(reportEventMessage({'type': 'assignment_changed', 'status': 'Assigned'}),
        'An enforcer was assigned to this report.');
    expect(reportEventMessage({'type': 'assignment_changed', 'status': 'Verified',
      'message': 'Request cancelled.'}), 'Request cancelled.');
    expect(reportEventMessage({'type': 'review_updated', 'status': 'Rejected',
      'message': 'Rejected for duplicate submission.'}), 'Rejected for duplicate submission.');
    expect(reportEventMessage({'message': '  On scene.  '}), 'On scene.');
  });
}
