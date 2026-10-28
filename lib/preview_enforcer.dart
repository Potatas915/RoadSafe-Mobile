// Design preview for the enforcer workspace using sample data.
//
// Run:  flutter run -d chrome -t lib/preview_enforcer.dart
//
// Nothing here talks to Supabase: all cases are fake and edits only live in
// memory until you restart the preview.
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'backend/backend.dart';
import 'backend/enforcer.dart';
import 'screens/enforcer_screen.dart';
import 'theme/roadsafe_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MapLibreMap.useHybridComposition = true;
  final backend = _PreviewBackend();
  runApp(
    MaterialApp(
      title: 'RoadTrack enforcer preview',
      debugShowCheckedModeBanner: false,
      theme: buildRoadSafeTheme(),
      builder: (context, child) => Banner(
        message: 'PREVIEW',
        location: BannerLocation.bottomEnd,
        child: child!,
      ),
      home: EnforcerScreen(backend: backend, service: _PreviewApi(backend)),
    ),
  );
}

String _ago(Duration d) => DateTime.now().subtract(d).toUtc().toIso8601String();

Map<String, dynamic> _report({
  required String id,
  required String category,
  required String status,
  required String address,
  required Duration ago,
  String? officer,
  Map<String, dynamic>? injuries,
  String vehicleStatus = 'unknown',
  List<Map<String, dynamic>> vehicles = const [],
  String description = '',
  bool verified = true,
  List<Map<String, dynamic>> events = const [],
}) => {
  'id': id,
  'version': 1,
  'categoryLabel': category,
  'status': status,
  'assignedOfficerId': officer,
  'isDuplicate': false,
  'reporter': {'userId': 'public'},
  'location': {
    'address': address,
    'coordinates': {'latitude': 14.8527, 'longitude': 120.8160},
  },
  'description': description,
  'officialRemarks': '',
  'verification': {'verifiedAt': verified ? _ago(ago) : null},
  'occurredAt': _ago(ago),
  'injuries': injuries ?? {'status': 'unknown'},
  'vehicleStatus': vehicleStatus,
  'vehicles': vehicles,
  'evidence': <Map<String, dynamic>>[],
  'events': events,
};

class _PreviewBackend extends RoadSafeBackend {
  final cases = <Map<String, dynamic>>[
    _report(
      id: '7c1e9a40-3b52-4d1e-9a77-0f8a1c2d3e41',
      category: 'Collision',
      status: 'Assigned',
      address: 'MacArthur Highway, Barangay Sumapang Matanda, Malolos',
      ago: const Duration(minutes: 35),
      officer: 'me',
      injuries: {'status': 'injured', 'injuredCount': 2},
      vehicleStatus: 'known',
      vehicles: [
        {'type': 'car', 'count': 2},
        {'type': 'motorcycle', 'count': 1},
      ],
      description:
          'Two cars and a motorcycle collided near the junction. One lane is blocked and two people are being helped by bystanders.',
      events: [
        {
          'status': 'Submitted',
          'createdAt': _ago(const Duration(minutes: 33)),
          'message': 'Report received.',
        },
        {
          'status': 'Verified',
          'createdAt': _ago(const Duration(minutes: 20)),
          'message': 'Confirmed by the response team.',
        },
        {
          'status': 'Assigned',
          'createdAt': _ago(const Duration(minutes: 12)),
          'message': 'Assigned to Officer Dela Cruz.',
        },
      ],
    ),
    _report(
      id: 'b2f6d3c8-91aa-4c0b-8e5d-2a6f7b9c1d02',
      category: 'Pedestrian accident',
      status: 'In Progress',
      address: 'Paseo del Congreso, Malolos, Bulacan',
      ago: const Duration(hours: 2, minutes: 10),
      officer: 'me',
      injuries: {'status': 'injured', 'injuredCount': 1, 'fatalityCount': 0},
      description: 'A pedestrian was hit while crossing. Ambulance requested.',
      events: [
        {
          'status': 'In Progress',
          'createdAt': _ago(const Duration(hours: 1, minutes: 50)),
          'message': 'Officer on scene.',
        },
      ],
    ),
    _report(
      id: 'e5a8c7d2-44bb-4f3a-b1c9-6d0e2f4a8b13',
      category: 'Hit-and-run',
      status: 'Submitted',
      address: 'Calumpit-Hagonoy Road, Calumpit',
      ago: const Duration(minutes: 8),
      verified: false,
      description:
          'A white van hit a parked tricycle and drove off toward Hagonoy.',
      vehicleStatus: 'known',
      vehicles: [
        {'type': 'van', 'count': 1},
        {'type': 'tricycle', 'count': 1},
      ],
    ),
    _report(
      id: 'f9d1b6a3-27cc-4e8d-a0f4-3c5b7d9e1a24',
      category: 'Other accident',
      status: 'Under Review',
      address: 'Plaridel Bypass Road, Plaridel',
      ago: const Duration(hours: 1, minutes: 5),
      verified: false,
      description: 'A truck lost its load on the bypass road.',
      vehicleStatus: 'known',
      vehicles: [
        {'type': 'truck', 'count': 1},
      ],
    ),
  ];
  @override
  String? get userId => 'me';
  @override
  Future<List<Map<String, dynamic>>> reports({bool ownOnly = true}) async =>
      cases.map((c) => Map<String, dynamic>.from(c)).toList();
  @override
  Future<void> signOut() async {}
}

class _PreviewApi extends EnforcerBackend {
  _PreviewApi(this.preview) : super(preview);
  final _PreviewBackend preview;
  String? station = 'node/1';
  bool onDuty = true;
  @override
  Future<void> heartbeat() async {}
  @override
  Future<Map<String, dynamic>> context() async => {
    'name': 'Officer Dela Cruz',
    'stationId': station,
    'onDuty': onDuty,
    'stations': [
      {
        'id': 'node/1',
        'name': 'Malolos City Police Station',
        'address': 'Paseo del Congreso, Malolos, Bulacan',
      },
      {
        'id': 'node/2',
        'name': 'Calumpit Municipal Police Station',
        'address': 'Poblacion, Calumpit, Bulacan',
      },
      {
        'id': 'node/3',
        'name': 'Plaridel Municipal Police Station',
        'address': 'Poblacion, Plaridel, Bulacan',
      },
    ],
  };
  @override
  Future<void> duty(
    String nextStation,
    bool nextDuty, {
    required String? expectedStationId,
  }) async {
    if (station != expectedStationId) throw StateError('Stale station');
    station = nextStation;
    onDuty = nextDuty;
  }

  @override
  Future<Map<String, dynamic>?> medicalRecommendation(String reportId) async =>
      {
        'selectedId': 'node/9',
        'facilities': [
          {
            'id': 'node/9',
            'name': 'Bulacan Medical Center',
            'kind': 'Hospital',
            'address': 'Hagonoy Road, Malolos',
            'lat': 14.8480,
            'lng': 120.8100,
            'distanceKm': 0.9,
          },
          {
            'id': 'node/10',
            'name': 'Malolos Community Clinic',
            'kind': 'Clinic',
            'address': 'Sto. Rosario, Malolos',
            'lat': 14.8560,
            'lng': 120.8200,
            'distanceKm': 1.4,
          },
        ],
      };
  @override
  Future<void> update(
    Map<String, dynamic> report,
    String status,
    String remarks,
  ) async {
    final index = preview.cases.indexWhere((c) => c['id'] == report['id']);
    if (index < 0) return;
    final next = Map<String, dynamic>.from(preview.cases[index]);
    next['status'] = status;
    next['officialRemarks'] = remarks.trim();
    next['version'] = (next['version'] as int) + 1;
    next['events'] = [
      ...(next['events'] as List),
      {
        'status': status,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'message': remarks.trim(),
      },
    ];
    preview.cases[index] = next;
  }
}
