import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_mobile/backend/format.dart';

void main() {
  test('assignment distinguishes inherited cancellation remarks from its action', () {
    final message = reportEventMessage({
      'type': 'assignment_changed', 'status': 'Assigned',
      'message': 'received\nPolice station request cancelled; officer unassigned.',
    });
    expect(message, startsWith('An enforcer was assigned to this report.'));
    expect(message, contains('Remarks on record (may include earlier updates):'));
    expect(message, contains('Police station request cancelled; officer unassigned.'));
  });
  test('empty assignment remarks and other event messages remain accurate', () {
    expect(reportEventMessage({'type': 'assignment_changed', 'status': 'Assigned'}),
        'An enforcer was assigned to this report.');
    expect(reportEventMessage({'type': 'assignment_changed', 'status': 'Verified',
      'message': 'Request cancelled.'}), 'Request cancelled.');
    expect(reportEventMessage({'type': 'review_updated', 'status': 'Rejected',
      'message': 'Rejected for duplicate submission.'}), 'Rejected for duplicate submission.');
    expect(reportEventMessage({'message': '  On scene.  '}), 'On scene.');
  });
}
