/// Validation for the reporter details collected on the report form.
///
/// Both functions return an error message, or null when the value is valid.

final _nameChars = RegExp(r"^[\p{L}\p{M}][\p{L}\p{M} .'’-]*$", unicode: true);
final _phoneChars = RegExp(r'^\+?[0-9\s\-().]+$');

String? validateReporterName(String? value) {
  final name = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.isEmpty) return 'Enter your full name';
  if (name.length > 60) return 'Use at most 60 characters';
  if (!_nameChars.hasMatch(name)) {
    return 'Use letters only (no numbers or symbols)';
  }
  final letters = name.replaceAll(RegExp(r"[ .'’-]"), '');
  if (letters.length < 4 || !name.contains(' ')) {
    return 'Enter your first and last name';
  }
  return null;
}

String? validateReporterContact(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Enter your contact number';
  const example = 'e.g. 0917 123 4567 or +63 917 123 4567';
  if (!_phoneChars.hasMatch(text)) {
    return 'Use numbers only, $example';
  }
  final digits = text.replaceAll(RegExp(r'\D'), '');
  final international = text.startsWith('+');
  // Philippine mobile: 09XXXXXXXXX, 639XXXXXXXXX or +639XXXXXXXXX.
  if (RegExp(r'^(09\d{9}|639\d{9})$').hasMatch(digits)) return null;
  // Philippine landline with area code, e.g. 02 8123 4567 or 044 123 4567.
  if (!international && RegExp(r'^0[2-8]\d{8,9}$').hasMatch(digits)) {
    return null;
  }
  // Other international numbers, written with a leading +.
  if (international && digits.length >= 8 && digits.length <= 15) return null;
  return 'Enter a valid phone number, $example';
}
