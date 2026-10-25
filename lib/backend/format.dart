/// Small date helpers shared by the resident screens.

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Oct 24, 2026 · 7:25 PM"
String formatWhen(Object? iso) {
  final date = DateTime.tryParse('$iso')?.toLocal();
  if (date == null) return iso == null ? 'Time not provided' : '$iso';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${_months[date.month - 1]} ${date.day}, ${date.year} · $hour:$minute $period';
}

/// "just now", "5 min ago", "3 h ago", "2 d ago", otherwise the full date.
String relativeWhen(Object? iso, {DateTime? now}) {
  final date = DateTime.tryParse('$iso')?.toLocal();
  if (date == null) return formatWhen(iso);
  final diff = (now ?? DateTime.now()).difference(date);
  if (diff.isNegative || diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return formatWhen(iso);
}
