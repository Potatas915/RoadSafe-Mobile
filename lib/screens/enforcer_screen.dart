import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../backend/backend.dart';
import '../backend/enforcer.dart';
import '../theme/roadsafe_theme.dart';

class EnforcerScreen extends StatefulWidget {
  const EnforcerScreen({super.key, this.backend, this.service});
  final RoadSafeBackend? backend;
  final EnforcerBackend? service;
  @override
  State<EnforcerScreen> createState() => _EnforcerScreenState();
}

class _EnforcerScreenState extends State<EnforcerScreen>
    with WidgetsBindingObserver {
  late final backend = widget.backend ?? RoadSafeBackend.instance;
  late final api = widget.service ?? EnforcerBackend(backend);
  Timer? timer;
  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> reports = [];
  String? station;
  String? error;
  bool onDuty = false, busy = false, foreground = true, verification = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) refresh();
  }

  Future<void> refresh() async {
    if (busy || !foreground) return;
    final current = ++generation;
    busy = true;
    try {
      final context = await api.context();
      final selected = context['stationId'] as String?;
      final duty = context['onDuty'] == true;
      if (selected != null) await api.duty(selected, duty);
      final feed = await backend.reports(ownOnly: false);
      if (!mounted || current != generation) return;
      setState(() {
        profile = context;
        station = selected;
        onDuty = duty;
        reports = feed;
        error = null;
      });
    } catch (failure) {
      if (mounted && current == generation) {
        setState(() {
          profile = null;
          reports = [];
          error =
              'Could not load current enforcer access. Refresh to retry. $failure';
        });
      }
    } finally {
      busy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> setDuty(String nextStation, bool nextDuty) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await api.duty(nextStation, nextDuty);
      if (mounted) {
        setState(() {
          station = nextStation;
          onDuty = nextDuty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not save duty. Finish active cases before changing station, then refresh and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cases = reports
        .where(
          (r) => verification
              ? canVerifyCase(r, backend.userId)
              : isOwnActiveCase(r, backend.userId),
        )
        .toList();
    final stations = profile?['stations'] as List? ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enforcer response'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: busy
                ? null
                : () async {
                    if (station != null) {
                      try {
                        await api.duty(station!, false);
                      } catch (_) {
                        /* Expiry still removes online presence. */
                      }
                    }
                    await backend.signOut();
                  },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              profile?['name'] as String? ?? 'Traffic enforcer',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Coordinate your assigned response and record what happened at the scene.',
              style: TextStyle(color: RoadSafeColors.muted),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR STATION',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy || profile == null
                          ? null
                          : () async {
                              final selected = await showSearch<String?>(
                                context: context,
                                delegate: _StationSearch(stations),
                              );
                              if (selected != null) {
                                await setDuty(selected, onDuty);
                              }
                            },
                      icon: const Icon(Icons.local_police_outlined),
                      label: Text(
                        stations
                                    .where((s) => s['id'] == station)
                                    .firstOrNull?['name']
                                as String? ??
                            'Select police station',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(onDuty ? 'On duty' : 'Off duty'),
                      subtitle: const Text(
                        'Available for assignment when online and without an active case.',
                      ),
                      value: onDuty,
                      onChanged: busy || station == null || profile == null
                          ? null
                          : (value) => setDuty(station!, value),
                    ),
                    const Text(
                      'Station is self-selected. Online means app activity within 90 seconds, not GPS presence.',
                      style: TextStyle(
                        fontSize: 12,
                        color: RoadSafeColors.muted,
                      ),
                    ),
                    if (profile != null && stations.isEmpty)
                      const Text(
                        'No stations shared yet. Ask an Admin to open a police station on the live map to publish its loaded directory.',
                      ),
                  ],
                ),
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.assignment_outlined),
                  label: Text('My cases'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.fact_check_outlined),
                  label: Text('Verify'),
                ),
              ],
              selected: {verification},
              onSelectionChanged: (value) =>
                  setState(() => verification = value.first),
            ),
            const SizedBox(height: 16),
            if (!busy && profile != null && cases.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No cases here. Pull down to refresh.'),
              ),
            ...cases.map(
              (report) => Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(
                    Icons.car_crash_outlined,
                    color: RoadSafeColors.orange,
                  ),
                  title: Text(report['categoryLabel'] as String? ?? 'Accident'),
                  subtitle: Text(
                    '${report['status']}\n${report['location']['address'] ?? 'Confirmed map location'}\n${report['id']}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy
                      ? null
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => _CaseScreen(
                                report: report,
                                backend: backend,
                                service: api,
                              ),
                            ),
                          );
                          await refresh();
                        },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationSearch extends SearchDelegate<String?> {
  _StationSearch(this.stations);
  final List stations;
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
            query.toLowerCase(),
          ),
        )
        .toList();
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final station = matches[index];
        return ListTile(
          title: Text(station['name'] as String),
          subtitle: Text('${station['address']}\n${station['id']}'),
          onTap: () => close(context, station['id'] as String),
        );
      },
    );
  }
}

class _CaseScreen extends StatefulWidget {
  const _CaseScreen({
    required this.report,
    required this.backend,
    required this.service,
  });
  final Map<String, dynamic> report;
  final RoadSafeBackend backend;
  final EnforcerBackend service;
  @override
  State<_CaseScreen> createState() => _CaseScreenState();
}

class _CaseScreenState extends State<_CaseScreen> {
  final remarks = TextEditingController();
  late final backend = widget.backend;
  Timer? accessTimer;
  bool accessible = true;
  int accessGeneration = 0;
  late Map<String, dynamic> currentReport = widget.report;
  Map<String, dynamic>? medicalRecommendation;
  String? medicalError;
  late String status;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    remarks.text = widget.report['officialRemarks'] as String? ?? '';
    status =
        enforcerStatuses(widget.report, backend.userId).firstOrNull ??
        widget.report['status'] as String;
    accessible = enforcerStatuses(widget.report, backend.userId).isNotEmpty;
    loadMedical();
    accessTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => checkAccess(),
    );
  }

  Future<void> loadMedical() async {
    if (currentReport['assignedOfficerId'] != backend.userId) return;
    try {
      final value = await widget.service.medicalRecommendation(
        currentReport['id'] as String,
      );
      if (mounted && accessible) {
        setState(() {
          medicalRecommendation = value;
          medicalError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          medicalRecommendation = null;
          medicalError = 'Could not load hospital/clinic information. Retry.';
        });
      }
    }
  }

  Future<void> checkAccess() async {
    final current = ++accessGeneration;
    try {
      await widget.service.context();
      final feed = await backend.reports(ownOnly: false);
      final report = feed
          .where((r) => r['id'] == widget.report['id'])
          .firstOrNull;
      if (mounted && current == accessGeneration) {
        setState(() {
          accessible =
              report != null &&
              enforcerStatuses(report, backend.userId).isNotEmpty;
          // Accept informational version updates without masking concurrent case edits.
          if (accessible &&
              report!['status'] == currentReport['status'] &&
              report['assignedOfficerId'] ==
                  currentReport['assignedOfficerId'] &&
              report['officialRemarks'] == currentReport['officialRemarks']) {
            currentReport = report;
          }
        });
        if (accessible) await loadMedical();
      }
    } catch (_) {
      if (mounted && current == accessGeneration) {
        setState(() => accessible = false);
      }
    }
  }

  @override
  void dispose() {
    accessGeneration++;
    accessTimer?.cancel();
    remarks.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.service.update(currentReport, status, remarks.text);
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) {
        setState(
          () => error =
              'Could not save: $failure. Return to the queue and refresh if this case changed.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!accessible) {
      return Scaffold(
        appBar: AppBar(title: const Text('Case unavailable')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Access changed or could not be confirmed. Return to your queue and refresh.',
          ),
        ),
      );
    }
    final report = currentReport;
    final coords = report['location']['coordinates'];
    final injuries = report['injuries'];
    return Scaffold(
      appBar: AppBar(title: const Text('Accident response')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            report['categoryLabel'] as String? ?? 'Accident',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          SelectableText(report['id'] as String),
          const SizedBox(height: 16),
          Text(
            '${report['status']} · ${report['verification']['verifiedAt'] == null ? 'Public report · not verified' : 'Officially verified'}',
          ),
          const SizedBox(height: 16),
          Text(
            report['location']['address'] as String? ??
                'Confirmed map location',
          ),
          SelectableText('${coords['latitude']}, ${coords['longitude']}'),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => _SceneMap(
                  latitude: (coords['latitude'] as num).toDouble(),
                  longitude: (coords['longitude'] as num).toDouble(),
                ),
              ),
            ),
            icon: const Icon(Icons.map_outlined),
            label: const Text('View accident map'),
          ),
          Text('Incident time: ${report['occurredAt']}'),
          if (report['assignedOfficerId'] == backend.userId) ...[
            const SizedBox(height: 16),
            MedicalRecommendationDetails(
              recommendation: medicalRecommendation,
              error: medicalError,
              onRetry: loadMedical,
              onMap: (lat, lng, name) => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => _SceneMap(
                    latitude: lat,
                    longitude: lng,
                    title: name,
                    facility: true,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(report['description'] as String),
          Text(
            'Injuries: ${injuries['status']} · Injured: ${injuries['injuredCount'] ?? 'Unknown'} · Fatalities: ${injuries['fatalityCount'] ?? 'Unknown'}',
          ),
          Text('Vehicles: ${report['vehicleStatus']} ${report['vehicles']}'),
          const SizedBox(height: 16),
          ...((report['evidence'] as List?) ?? []).map(
            (file) => OutlinedButton.icon(
              onPressed: () async {
                try {
                  final url = await backend.evidenceUrl(
                    file['storagePath'] as String,
                  );
                  if (!context.mounted) return;
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Report evidence'),
                      content: Image.network(
                        url,
                        errorBuilder: (_, error, stack) =>
                            const Text('Photo unavailable. Close and retry.'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                } catch (_) {
                  if (mounted) {
                    setState(
                      () => error =
                          'Photo unavailable. Refresh access and retry.',
                    );
                  }
                }
              },
              icon: const Icon(Icons.photo_outlined),
              label: Text(file['fileName'] as String),
            ),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Response status'),
            items: enforcerStatuses(report, backend.userId)
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s == 'In Progress'
                          ? 'In Progress · Responding / on scene'
                          : s,
                    ),
                  ),
                )
                .toList(),
            onChanged: saving
                ? null
                : (value) => setState(() => status = value!),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: remarks,
            enabled: !saving,
            minLines: 5,
            maxLines: 10,
            maxLength: 5000,
            decoration: const InputDecoration(
              labelText: 'Official remarks, findings and actions taken',
              hintText:
                  'Arrival at scene, observations, assistance provided and next steps.',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Case history',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          ...((report['events'] as List?) ?? []).map(
            (event) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${event['status'] ?? event['type']}'),
              subtitle: Text(
                '${event['createdAt']}\n${event['message'] ?? ''}',
              ),
            ),
          ),
          const Text(
            'Updates are saved to case history and permitted reporter notifications. Assignment does not contact external emergency services.',
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              saving
                  ? 'Saving…'
                  : status == 'Verified'
                  ? 'Verify accident information'
                  : 'Save response update',
            ),
          ),
        ],
      ),
    );
  }
}

class MedicalRecommendationDetails extends StatelessWidget {
  const MedicalRecommendationDetails({
    super.key,
    this.recommendation,
    this.error,
    required this.onRetry,
    required this.onMap,
  });
  final Map<String, dynamic>? recommendation;
  final String? error;
  final VoidCallback onRetry;
  final void Function(double, double, String) onMap;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nearby hospitals & clinics',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          if (error != null) ...[
            Text(error!),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry facility information'),
            ),
          ] else if (recommendation == null)
            const Text(
              'No facility recommendation has been added for this case.',
            )
          else
            ...((recommendation!['facilities'] as List?) ?? []).map((value) {
              final facility = Map<String, dynamic>.from(value as Map);
              final selected = facility['id'] == recommendation!['selectedId'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${facility['name']}${selected ? ' · Recommended' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${facility['kind']} · ${(facility['distanceKm'] as num).toStringAsFixed(1)} km straight-line distance',
                    ),
                    Text(facility['address'] as String? ?? ''),
                    SelectableText('${facility['lat']}, ${facility['lng']}'),
                    TextButton.icon(
                      onPressed: () => onMap(
                        (facility['lat'] as num).toDouble(),
                        (facility['lng'] as num).toDouble(),
                        facility['name'] as String,
                      ),
                      icon: const Icon(Icons.local_hospital_outlined),
                      label: const Text('View facility location'),
                    ),
                  ],
                ),
              );
            }),
          const Text(
            'Mapped locations only. Opening hours, capacity and acceptance are unconfirmed.',
          ),
        ],
      ),
    ),
  );
}

class _SceneMap extends StatelessWidget {
  const _SceneMap({
    required this.latitude,
    required this.longitude,
    this.title = 'Accident location',
    this.facility = false,
  });
  final double latitude, longitude;
  final String title;
  final bool facility;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            facility
                ? 'Mapped facility: $latitude, $longitude\nLocation information only. Capacity and acceptance are unconfirmed.'
                : 'Confirmed accident pin: $latitude, $longitude\nMap tiles require internet. This is the reported scene, not live enforcer tracking.',
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              MapLibreMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(latitude, longitude),
                  zoom: 15.5,
                ),
                styleString:
                    'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json',
                scrollGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
              ),
              const IgnorePointer(
                child: Icon(
                  Icons.location_on,
                  color: RoadSafeColors.orange,
                  size: 44,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
