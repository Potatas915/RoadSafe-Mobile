import 'package:flutter/material.dart';
import '../theme/roadsafe_theme.dart';

class StationSearch extends SearchDelegate<String?> {
  StationSearch(this.stations);
  final List stations;
  @override
  String get searchFieldLabel => 'Search police stations';
  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
  ];
  @override
  Widget buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );
  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);
  @override
  Widget buildSuggestions(BuildContext context) {
    final matches = stations
        .where(
          (s) => '${s['name']} ${s['address']}'.toLowerCase().contains(
            query.trim().toLowerCase(),
          ),
        )
        .toList();
    if (matches.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No stations match your search.',
            style: TextStyle(color: RoadSafeColors.muted),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: matches.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: RoadSafeColors.border),
      itemBuilder: (context, index) {
        final station = matches[index];
        return ListTile(
          leading: const Icon(
            Icons.local_police_outlined,
            color: RoadSafeColors.orange,
          ),
          title: Text(
            station['name'] as String,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${station['address'] ?? ''}',
            style: const TextStyle(color: RoadSafeColors.muted, fontSize: 12),
          ),
          onTap: () => close(context, station['id'] as String),
        );
      },
    );
  }
}
