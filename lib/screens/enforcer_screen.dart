import 'dart:async';
import '../widgets/station_search.dart';
import 'package:flutter/material.dart';
import 'scene_map.dart';
import '../backend/backend.dart';
import '../backend/enforcer.dart';
import '../theme/roadsafe_theme.dart';
import '../widgets/roadsafe_logo.dart';

const _errorColor = Color(0xFFF87171);
const _blue = Color(0xFF60A5FA);
const _amber = Color(0xFFFBBF24);

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

String _when(Object? iso) {
  final date = DateTime.tryParse('$iso')?.toLocal();
  if (date == null) return iso == null ? 'Time not provided' : '$iso';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${_months[date.month - 1]} ${date.day}, ${date.year} · $hour:$minute $period';
}

Color _statusColor(String status) {
  switch (status) {
    case 'Assigned':
    case 'In Progress':
    case 'Verified':
      return _blue;
    case 'Resolved / Closed':
      return RoadSafeColors.green;
    default:
      return _amber;
  }
}

String _responseLabel(String status) => switch (status) {
  'Assigned' || 'In Progress' => 'Responding',
  'Resolved / Closed' => 'Complete',
  _ => status,
};

String _injuryLabel(Object? status) {
  switch (status) {
    case 'none':
      return 'No injuries';
    case 'injured':
      return 'Someone is hurt';
    case 'fatal':
      return 'Fatality reported';
    default:
      return 'Not sure';
  }
}

String _vehicleText(Map<String, dynamic> report) {
  final status = report['vehicleStatus'];
  if (status == 'not_applicable') return 'No vehicles involved';
  final list = (report['vehicles'] as List?) ?? const [];
  if (status != 'known' || list.isEmpty) return 'Not reported';
  return list
      .map((value) {
        final item = value is Map ? value : const {};
        return '${item['count'] ?? '?'} × ${item['type'] ?? 'vehicle'}';
      })
      .join(', ');
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label, {this.color, this.icon});
  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? _statusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tint),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              _responseLabel(label),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tint,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _panel({String? title, required Widget child, Color? borderColor}) =>
    Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RoadSafeColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? RoadSafeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: RoadSafeColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );

Widget _banner(IconData icon, Color color, Widget child) => Container(
  width: double.infinity,
  margin: const EdgeInsets.only(bottom: 14),
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: color.withValues(alpha: 0.35)),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Expanded(child: child),
    ],
  ),
);

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
  bool onDuty = false, busy = false, foreground = true;
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
      await api.heartbeat();
      final context = await api.context();
      final selected = context['stationId'] as String?;
      final duty = context['onDuty'] == true;
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
      await api.duty(nextStation, nextDuty, expectedStationId: station);
      if (mounted) {
        setState(() {
          station = nextStation;
          onDuty = nextDuty;
        });
      }
    } catch (_) {
      // A transfer may have invalidated this write; never retry its old station.
      try {
        final context = await api.context();
        if (mounted) {
          setState(() {
            profile = context;
            station = context['stationId'] as String?;
            onDuty = context['onDuty'] == true;
            reports = [];
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            profile = null;
            reports = [];
          });
        }
      }
      if (mounted) {
        setState(
          () => error =
              'Could not save duty. Your station may have changed or active cases may prevent this change. Refresh and retry.',
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

  Future<void> _pickStation(List stations) async {
    final selected = await showSearch<String?>(
      context: context,
      delegate: StationSearch(stations),
    );
    if (selected != null) {
      await setDuty(selected, onDuty);
    }
  }

  Future<void> _signOut() async {
    if (station != null) {
      try {
        await api.duty(station!, false, expectedStationId: station);
      } catch (_) {
        /* Expiry still removes online presence. */
      }
    }
    await backend.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final uid = backend.userId;
    final mine = reports.where((r) => isOwnActiveCase(r, uid)).toList();
    final cases = mine;
    final stations = profile?['stations'] as List? ?? [];
    final stationName =
        stations.where((s) => s['id'] == station).firstOrNull?['name']
            as String?;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            RoadSafeLogo(size: 30),
            SizedBox(width: 10),
            Expanded(child: Text('Enforcer response', overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: busy ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const Text(
              'TRAFFIC ENFORCER',
              style: TextStyle(
                color: RoadSafeColors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              profile?['name'] as String? ?? 'Traffic enforcer',
              style: const TextStyle(
                fontSize: 26,
                height: 1.15,
                letterSpacing: -0.6,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Coordinate your assigned response and record what happened at the scene.',
              style: TextStyle(
                color: RoadSafeColors.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _dutyCard(stations, stationName),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: LinearProgressIndicator(),
              ),
            if (error != null)
              _banner(
                Icons.error_outline,
                _errorColor,
                Text(error!, style: const TextStyle(fontSize: 12.5, height: 1.5)),
              ),
            Row(
              children: [
                const Text('My cases', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('${mine.length}', style: const TextStyle(color: RoadSafeColors.orange, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 14),
            if (!busy && profile != null && cases.isEmpty) _empty(),
            ...cases.map(_caseCard),
          ],
        ),
      ),
    );
  }

  Widget _dutyCard(List stations, String? stationName) {
    final canEdit = !busy && profile != null;
    return _panel(
      borderColor: onDuty
          ? RoadSafeColors.green.withValues(alpha: 0.5)
          : RoadSafeColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: onDuty
                      ? RoadSafeColors.green
                      : RoadSafeColors.muted.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  onDuty ? 'On duty' : 'Off duty',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Switch(
                value: onDuty,
                onChanged: busy || station == null || profile == null
                    ? null
                    : (value) => setDuty(station!, value),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Available for assignment when online and without an active case.',
            style: TextStyle(
              color: RoadSafeColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: RoadSafeColors.background,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: canEdit ? () => _pickStation(stations) : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: RoadSafeColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: RoadSafeColors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_police_outlined,
                        size: 20,
                        color: RoadSafeColors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your station',
                            style: TextStyle(
                              color: RoadSafeColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stationName ?? 'Select police station',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: RoadSafeColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Station is self-selected. Online means app activity within 90 seconds, not GPS presence.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: RoadSafeColors.muted,
            ),
          ),
          if (profile != null && stations.isEmpty) ...[
            const SizedBox(height: 12),
            _banner(
              Icons.info_outline,
              _amber,
              const Text(
                'No stations shared yet. Ask an Admin to open a police station on the live map to publish its loaded directory.',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _empty() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 36, horizontal: 12),
    child: Column(
      children: [
        Icon(
          Icons.assignment_turned_in_outlined,
          size: 40,
          color: RoadSafeColors.muted,
        ),
        SizedBox(height: 14),
        Text(
          'No cases here',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 6),
        Text(
          'When an Admin assigns you a report, it will appear here. Pull down to refresh.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: RoadSafeColors.muted,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
      ],
    ),
  );

  Widget _caseCard(Map<String, dynamic> report) {
    final status = '${report['status']}';
    final address =
        report['location']['address'] as String? ?? 'Confirmed map location';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: RoadSafeColors.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: busy
              ? null
              : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _CaseScreen(
                        report: report,
                        station: (profile?['stations'] as List? ?? []).where((row) => row['id'] == station).firstOrNull,
                        backend: backend,
                        service: api,
                      ),
                    ),
                  );
                  await refresh();
                },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: RoadSafeColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: RoadSafeColors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.car_crash_outlined,
                        color: RoadSafeColors.orange,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        report['categoryLabel'] as String? ?? 'Accident',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: RoadSafeColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: RoadSafeColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusChip(status),
                    Text(
                      '${_when(report['occurredAt'])}  ·  #${report['id']}',
                      style: const TextStyle(
                        color: RoadSafeColors.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CaseScreen extends StatefulWidget {
  const _CaseScreen({
    required this.report,
    this.station,
    required this.backend,
    required this.service,
  });
  final Map<String, dynamic> report;
  final Map? station;
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

  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    remarks.text = widget.report['officialRemarks'] as String? ?? '';
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
      await widget.service.complete(currentReport, remarks.text);
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

  Future<void> _showEvidence(Map file) async {
    try {
      final url = await backend.evidenceUrl(file['storagePath'] as String);
      if (!mounted) return;
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
        setState(() => error = 'Photo unavailable. Refresh access and retry.');
      }
    }
  }

  Widget _fact(String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: RoadSafeColors.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: RoadSafeColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: RoadSafeColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!accessible) {
      return Scaffold(
        appBar: AppBar(title: const Text('Case unavailable')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: _banner(
            Icons.lock_outline,
            _amber,
            const Text(
              'Access changed or could not be confirmed. Return to your queue and refresh.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ),
      );
    }
    final report = currentReport;
    final coords = report['location']['coordinates'];
    final injuries = report['injuries'];
    final verified = report['verification']['verifiedAt'] != null;
    final events = (report['events'] as List?) ?? [];
    final evidence = (report['evidence'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Accident response')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: RoadSafeColors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.car_crash_outlined,
                        color: RoadSafeColors.orange,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        report['categoryLabel'] as String? ?? 'Accident',
                        style: const TextStyle(
                          fontSize: 22,
                          height: 1.15,
                          letterSpacing: -0.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip('${report['status']}'),
                    _StatusChip(
                      verified
                          ? 'Officially verified'
                          : 'Public report · not verified',
                      color: verified ? RoadSafeColors.green : _amber,
                      icon: verified
                          ? Icons.verified_outlined
                          : Icons.hourglass_empty,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  report['id'] as String,
                  style: const TextStyle(
                    color: RoadSafeColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _panel(
            title: 'Location and time',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: RoadSafeColors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        report['location']['address'] as String? ??
                            'Confirmed map location',
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: SelectableText(
                    '${coords['latitude']}, ${coords['longitude']}',
                    style: const TextStyle(
                      color: RoadSafeColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 18,
                      color: RoadSafeColors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _when(report['occurredAt']),
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => SceneMap(
                          station: widget.station,
                          latitude: (coords['latitude'] as num).toDouble(),
                          longitude: (coords['longitude'] as num).toDouble(),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('View accident map'),
                  ),
                ),
              ],
            ),
          ),
          _panel(
            title: 'What happened',
            child: Text(
              report['description'] as String,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
          _panel(
            title: 'People and vehicles',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final half = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth,
                      child: _fact('Injuries', _injuryLabel(injuries['status'])),
                    ),
                    SizedBox(
                      width: half,
                      child: _fact(
                        'Injured',
                        '${injuries['injuredCount'] ?? 'Unknown'}',
                      ),
                    ),
                    SizedBox(
                      width: half,
                      child: _fact(
                        'Fatalities',
                        '${injuries['fatalityCount'] ?? 'Unknown'}',
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth,
                      child: _fact('Vehicles', _vehicleText(report)),
                    ),
                  ],
                );
              },
            ),
          ),
          if (evidence.isNotEmpty)
            _panel(
              title: 'Photos from the reporter',
              child: Column(
                children: evidence
                    .map(
                      (file) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showEvidence(file as Map),
                            icon: const Icon(Icons.photo_outlined),
                            label: Text(
                              file['fileName'] as String,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (report['assignedOfficerId'] == backend.userId)
            MedicalRecommendationDetails(
              recommendation: medicalRecommendation,
              error: medicalError,
              onRetry: loadMedical,
              onMap: (lat, lng, name) => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SceneMap(
                    latitude: lat,
                    longitude: lng,
                    title: name,
                    facility: true,
                  ),
                ),
              ),
            ),
          if (events.isNotEmpty)
            _panel(
              title: 'Case history',
              child: Column(
                children: [
                  for (var i = 0; i < events.length; i++)
                    _timelineRow(events[i], last: i == events.length - 1),
                ],
              ),
            ),
          _panel(
            title: 'Your response',
            borderColor: RoadSafeColors.orange.withValues(alpha: 0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    alignLabelWithHint: true,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  _banner(
                    Icons.error_outline,
                    _errorColor,
                    Text(
                      error!,
                      style: const TextStyle(fontSize: 12.5, height: 1.5),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: saving ? null : save,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      saving ? 'Completing…' : 'Complete',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Updates are saved to case history and permitted reporter notifications. Assignment does not contact external emergency services.',
                  style: TextStyle(
                    color: RoadSafeColors.muted,
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineRow(Object? event, {required bool last}) {
    final data = event is Map ? event : const {};
    final title = '${data['status'] ?? data['type'] ?? 'Update'}';
    final message = '${data['message'] ?? ''}'.trim();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: RoadSafeColors.orange,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: RoadSafeColors.border,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _when(data['createdAt']),
                    style: const TextStyle(
                      color: RoadSafeColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ],
              ),
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
  Widget build(BuildContext context) => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.local_hospital_outlined,
              size: 20,
              color: RoadSafeColors.orange,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nearby hospitals & clinics',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (error != null) ...[
          Text(error!, style: const TextStyle(color: _errorColor)),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry facility information'),
          ),
        ] else if (recommendation == null)
          const Text(
            'No facility recommendation has been added for this case.',
            style: TextStyle(color: RoadSafeColors.muted, fontSize: 13),
          )
        else
          ...((recommendation!['facilities'] as List?) ?? []).map((value) {
            final facility = Map<String, dynamic>.from(value as Map);
            final selected = facility['id'] == recommendation!['selectedId'];
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? RoadSafeColors.green.withValues(alpha: 0.08)
                    : RoadSafeColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? RoadSafeColors.green.withValues(alpha: 0.4)
                      : RoadSafeColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${facility['name']}${selected ? ' · Recommended' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${facility['kind']} · ${(facility['distanceKm'] as num).toStringAsFixed(1)} km straight-line distance',
                    style: const TextStyle(
                      color: RoadSafeColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  if ('${facility['address'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      facility['address'] as String,
                      style: const TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 4),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => onMap(
                      (facility['lat'] as num).toDouble(),
                      (facility['lng'] as num).toDouble(),
                      facility['name'] as String,
                    ),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('View facility location'),
                  ),
                ],
              ),
            );
          }),
        const Text(
          'Mapped locations only. Opening hours, capacity and acceptance are unconfirmed.',
          style: TextStyle(
            color: RoadSafeColors.muted,
            fontSize: 11.5,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
