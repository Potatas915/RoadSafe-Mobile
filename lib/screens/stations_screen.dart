import 'package:flutter/material.dart';
import '../theme/roadsafe_theme.dart';

class StationsScreen extends StatelessWidget {
  const StationsScreen({super.key});

  static const _stations = [
    ('Central Precinct 1', '0.8 km', 'Active patrolling'),
    ('Highway Patrol HQ', '2.4 km', 'Available'),
    ('District 4 Police Station', '4.1 km', 'Active patrolling'),
    ('North Express Traffic Outpost', '5.7 km', 'Available'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Police Stations')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Nearby assistance',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Police stations and traffic response units.',
              style: TextStyle(color: RoadSafeColors.muted, height: 1.5)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RoadSafeColors.orange.withValues(alpha: 0.08),
              border: Border.all(
                  color: RoadSafeColors.orange.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
                'Demo directory · Names, distances and availability are sample data.',
                style: TextStyle(
                    color: RoadSafeColors.orange, fontSize: 12, height: 1.5)),
          ),
          const SizedBox(height: 20),
          ..._stations.map((station) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: RoadSafeColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: RoadSafeColors.border),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: RoadSafeColors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_police_outlined,
                        color: RoadSafeColors.orange),
                  ),
                  title: Text(station.$1,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(spacing: 10, runSpacing: 6, children: [
                      Text(station.$2,
                          style: const TextStyle(
                              color: RoadSafeColors.muted, fontSize: 12)),
                      Text(station.$3,
                          style: const TextStyle(
                              color: RoadSafeColors.green, fontSize: 12)),
                    ]),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
