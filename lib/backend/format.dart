// Display helpers shared by the resident screens.

String reportEventMessage(Map event) {
  var message = '${event['message'] ?? ''}'.trim();
  // Later response events inherit cumulative remarks from earlier cancellations.
  // Keep the actual cancellation event and immutable stored messages unchanged.
  if (['Assigned', 'In Progress', 'Resolved / Closed'].contains(event['status'])) {
    message = message.split('\n').where((line) =>
      line.trim() != 'Police station request cancelled; officer unassigned.'
    ).join('\n').trim();
  }
  if (event['type'] == 'assignment_changed' && event['status'] == 'Assigned') {
    return 'An enforcer was assigned to this report.'
        '${message.isEmpty ? '' : '\nRemarks on record (may include earlier updates):\n$message'}';
  }
  return message;
}

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
