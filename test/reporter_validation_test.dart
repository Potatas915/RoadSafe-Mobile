import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_mobile/backend/reporter_validation.dart';

void main() {
  group('reporter name', () {
    test('accepts normal full names', () {
      for (final name in [
        'Juan Dela Cruz',
        ' Fixture Reporter ',
        'Maria-Clara Santos',
        "Ma. Ana O'Brien",
        'Niño Peña',
      ]) {
        expect(validateReporterName(name), isNull, reason: name);
      }
    });

    test('rejects empty, short, numeric and single-word names', () {
      expect(validateReporterName(''), 'Enter your full name');
      expect(validateReporterName('   '), 'Enter your full name');
      expect(validateReporterName('aa'), isNotNull);
      expect(validateReporterName('Juan'), isNotNull);
      expect(validateReporterName('a b'), isNotNull);
      expect(validateReporterName('Juan 123'), isNotNull);
      expect(validateReporterName('J@n D!e'), isNotNull);
      expect(validateReporterName('${'a' * 40} ${'b' * 40}'), isNotNull);
    });
  });

  group('reporter contact', () {
    test('accepts Philippine mobile and landline numbers', () {
      for (final number in [
        '09000000000',
        '0917 123 4567',
        '0917-123-4567',
        '+63 917 123 4567',
        '639171234567',
        '(02) 8123 4567',
        '044 123 4567',
        '+1 415 555 0132',
      ]) {
        expect(validateReporterContact(number), isNull, reason: number);
      }
    });

    test('rejects empty, short, lettered and malformed numbers', () {
      expect(validateReporterContact(''), 'Enter your contact number');
      expect(validateReporterContact('aa'), isNotNull);
      expect(validateReporterContact('12345'), isNotNull);
      expect(validateReporterContact('0917 123 456'), isNotNull);
      expect(validateReporterContact('0917 123 45678'), isNotNull);
      expect(validateReporterContact('call me'), isNotNull);
      expect(validateReporterContact('+63'), isNotNull);
    });
  });
}
