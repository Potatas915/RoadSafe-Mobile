String normalizeUsername(String value) => value.trim().toLowerCase();

bool validUsername(String value) =>
    RegExp(r'^[a-z][a-z0-9_]{2,23}$').hasMatch(normalizeUsername(value));

String loginIdentity(String value) {
  final username = normalizeUsername(value);
  // Existing email-based accounts retain their original login identity.
  if (username.contains('@')) return username;
  if (!validUsername(username)) {
    throw const FormatException(
      'Use 3–24 letters, numbers or underscores; start with a letter.',
    );
  }
  return '$username@roadsafe.local';
}
