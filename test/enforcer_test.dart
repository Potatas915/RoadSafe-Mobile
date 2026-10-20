import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_mobile/backend/enforcer.dart';

void main() {
  Map<String, dynamic> report() => {
    'reporter': {'userId': 'public'},
    'assignedOfficerId': null,
    'isDuplicate': false,
    'status': 'Submitted',
  };
  test(
    'verification excludes self, duplicates, assigned cases and signed-out users',
    () {
      expect(canVerifyCase(report(), 'officer'), isTrue);
      expect(canVerifyCase(report(), 'public'), isFalse);
      expect(canVerifyCase(report(), null), isFalse);
      expect(
        canVerifyCase({...report(), 'isDuplicate': true}, 'officer'),
        isFalse,
      );
      expect(
        canVerifyCase({...report(), 'assignedOfficerId': 'other'}, 'officer'),
        isFalse,
      );
      expect(
        canVerifyCase({...report(), 'status': 'Verified'}, 'officer'),
        isFalse,
      );
    },
  );
  test('response transitions permit only own active assignments', () {
    final assigned = {
      ...report(),
      'assignedOfficerId': 'officer',
      'status': 'Assigned',
    };
    expect(enforcerStatuses(assigned, 'officer'), ['Assigned', 'In Progress']);
    expect(
      enforcerStatuses({...assigned, 'status': 'In Progress'}, 'officer'),
      ['In Progress', 'Resolved / Closed'],
    );
    expect(enforcerStatuses(assigned, 'other'), isEmpty);
    expect(
      enforcerStatuses({...assigned, 'status': 'Resolved / Closed'}, 'officer'),
      isEmpty,
    );
    expect(enforcerStatuses(report(), 'officer'), ['Verified']);
  });
}
