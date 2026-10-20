const defaultCategoryLabels = <String, String>{
  'collision': 'Collision',
  'hit-and-run': 'Hit-and-run',
  'rollover': 'Vehicle rollover',
  'pedestrian': 'Pedestrian accident',
  'other': 'Other accident',
};

class AccidentCategory {
  const AccidentCategory(this.id, this.label, this.enabled);
  final String id;
  final String label;
  final bool enabled;
}

final defaultCategories = defaultCategoryLabels.entries
    .map((entry) => AccidentCategory(entry.key, entry.value, true))
    .toList(growable: false);

List<AccidentCategory> parseCategories(List<dynamic> rows) {
  if (rows.length != defaultCategories.length) {
    throw const FormatException('Incomplete category catalog.');
  }
  return defaultCategoryLabels.keys
      .map((id) {
        final matches = rows.where((row) => row is Map && row['id'] == id);
        if (matches.length != 1) {
          throw const FormatException('Invalid category catalog.');
        }
        final row = matches.single as Map;
        final label = row['label'];
        if (label is! String ||
            label.trim().isEmpty ||
            label.length > 60 ||
            RegExp(r'[\x00-\x1f\x7f]').hasMatch(label) ||
            row['enabled'] is! bool) {
          throw const FormatException('Invalid category catalog.');
        }
        return AccidentCategory(id, label, row['enabled'] as bool);
      })
      .toList(growable: false);
}
