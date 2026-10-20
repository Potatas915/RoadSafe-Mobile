import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/roadsafe_theme.dart';
import 'backend.dart';
import 'account_screen.dart';

class MyReportsPreview extends StatefulWidget {
  const MyReportsPreview({super.key});
  @override
  State<MyReportsPreview> createState() => _MyReportsPreviewState();
}

class _MyReportsPreviewState extends State<MyReportsPreview> {
  final backend = RoadSafeBackend.instance;
  Timer? _timer;
  List<Map<String, dynamic>> _reports = [];
  String? _owner;
  String? _error;
  bool _loading = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    backend.addListener(_refresh);
    _timer = backend.ready
        ? Timer.periodic(const Duration(seconds: 15), (_) => _refresh())
        : null;
    _refresh();
  }

  @override
  void dispose() {
    _request++;
    _timer?.cancel();
    backend.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final request = ++_request;
    if (_owner != backend.userId) {
      _reports = [];
      _owner = backend.userId;
    }
    if (!backend.ready || !backend.signedIn) {
      if (mounted) setState(() {});
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await backend.reports();
      if (mounted && request == _request) setState(() => _reports = reports);
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _error =
              'Could not refresh your reports. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: RoadSafeColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: RoadSafeColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!backend.signedIn) ...[
          const Icon(
            Icons.receipt_long_outlined,
            color: RoadSafeColors.muted,
            size: 30,
          ),
          const SizedBox(height: 12),
          const Text(
            'Report updates will appear here',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in to see your reports and updates from the RoadSafe team.',
            style: TextStyle(
              color: RoadSafeColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          TextButton(
            onPressed: !backend.ready
                ? null
                : () async {
                    await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const AccountScreen()),
                    );
                    await _refresh();
                  },
            child: const Text('Sign in / Create account'),
          ),
          if (backend.initializationError != null)
            Text(backend.initializationError!),
        ] else ...[
          Text(
            backend.username ?? 'Your account',
            style: const TextStyle(color: RoadSafeColors.muted, fontSize: 12),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: RoadSafeColors.orange)),
          if (!_loading && _reports.isEmpty && _error == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No reports yet. Your submitted accidents will appear here.',
              ),
            ),
          ..._reports
              .take(3)
              .map(
                (report) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.assignment_outlined,
                    color: RoadSafeColors.orange,
                  ),
                  title: Text(report['status'] as String),
                  subtitle: Text(
                    report['description'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportTrackingScreen(
                          reportId: report['id'] as String,
                        ),
                      ),
                    );
                    await _refresh();
                  },
                ),
              ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReportTrackingScreen(),
                    ),
                  );
                  await _refresh();
                },
                child: const Text('All reports & updates'),
              ),
              TextButton(onPressed: _refresh, child: const Text('Refresh')),
              TextButton(
                onPressed: () async {
                  try {
                    await backend.signOut();
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => _error = 'Could not sign out. Please retry.',
                      );
                    }
                  }
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class ReportTrackingScreen extends StatefulWidget {
  const ReportTrackingScreen({super.key, this.reportId});
  final String? reportId;
  @override
  State<ReportTrackingScreen> createState() => _ReportTrackingScreenState();
}

class _ReportTrackingScreenState extends State<ReportTrackingScreen> {
  final backend = RoadSafeBackend.instance;
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _updates = [];
  Timer? _timer;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = backend.ready
        ? Timer.periodic(const Duration(seconds: 15), (_) => _refresh())
        : null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        backend.reports(),
        backend.notifications(),
      ]);
      if (mounted) {
        setState(() {
          _reports = results[0];
          _updates = results[1];
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not load your reports: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clarify(String id) async {
    final text = TextEditingController();
    final response = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Additional information'),
        content: TextField(
          controller: text,
          maxLines: 4,
          maxLength: 5000,
          decoration: const InputDecoration(
            hintText: 'Provide the information requested by the team.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (text.text.trim().isNotEmpty) {
                Navigator.pop(context, text.text.trim());
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    // Allow the dialog's closing animation to release its text field first.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    text.dispose();
    if (response == null || !mounted) return;
    try {
      await backend.clarify(id, response);
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not send your clarification: $error');
      }
    }
  }

  Future<void> _viewEvidence(String path) async {
    try {
      final url = await backend.evidenceUrl(path);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Photo could not be loaded. Close and retry.',
                      ),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close photo'),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not open the photo: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = _reports
        .where(
          (report) =>
              widget.reportId == null || report['id'] == widget.reportId,
        )
        .toList();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your reports & updates'),
          actions: [
            IconButton(
              tooltip: 'Refresh reports',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Reports'),
              Tab(text: 'Updates'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: RoadSafeColors.orange),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (!_busy && reports.isEmpty)
                        const Text('No reports to show.'),
                      ...reports.map(
                        (report) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report['status'] as String,
                                  style: const TextStyle(
                                    color: RoadSafeColors.orange,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  report['categoryLabel'] as String? ??
                                      report['categoryId'] as String,
                                ),
                                Text(report['description'] as String),
                                const SizedBox(height: 8),
                                Text(
                                  'Vehicles: ${report['vehicleStatus'] == 'not_applicable'
                                      ? 'Not applicable'
                                      : (report['vehicles'] as List? ?? []).isEmpty
                                      ? 'Unknown'
                                      : (report['vehicles'] as List).map((v) => '${v['count']} × ${v['type']}').join(', ')}',
                                ),
                                Text(
                                  'Injured: ${report['injuries']?['injuredCount'] ?? 'Unknown'}; fatalities: ${report['injuries']?['fatalityCount'] ?? 'Unknown'}',
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  'Reference: ${report['id']}',
                                  style: const TextStyle(
                                    color: RoadSafeColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                                if (report['officialRemarks'] != '')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      'Team update: ${report['officialRemarks']}',
                                    ),
                                  ),
                                if (report['isDuplicate'] == true)
                                  const Text('Marked as a duplicate report'),
                                if (report['rejectionReason'] != null)
                                  Text('Reason: ${report['rejectionReason']}'),
                                if (report['status'] ==
                                    'Additional Information Required')
                                  TextButton(
                                    onPressed: () =>
                                        _clarify(report['id'] as String),
                                    child: const Text(
                                      'Provide additional information',
                                    ),
                                  ),
                                ...((report['evidence'] as List).map(
                                  (file) => TextButton.icon(
                                    onPressed: () => _viewEvidence(
                                      file['storagePath'] as String,
                                    ),
                                    icon: const Icon(Icons.photo_outlined),
                                    label: Text(file['fileName'] as String),
                                  ),
                                )),
                                const Divider(),
                                ...((report['events'] as List).map(
                                  (event) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      '${event['type'] == 'facts_corrected' ? 'Incident facts corrected' : event['status'] ?? event['type']}\n${event['message']}\n${DateTime.parse(event['createdAt'] as String).toLocal()}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: RoadSafeColors.muted,
                                      ),
                                    ),
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (!_busy && _updates.isEmpty)
                        const Text('No updates yet.'),
                      ..._updates.map(
                        (update) => ListTile(
                          leading: Icon(
                            update['read_at'] == null
                                ? Icons.notifications_active_outlined
                                : Icons.notifications_none,
                          ),
                          title: Text(update['message'] as String),
                          subtitle: Text(
                            DateTime.parse(
                              update['created_at'] as String,
                            ).toLocal().toString(),
                          ),
                          onTap: () async {
                            try {
                              await backend.markRead(update['id'] as int);
                              await _refresh();
                            } catch (_) {
                              if (mounted) {
                                setState(
                                  () => _error =
                                      'Could not mark the update as read.',
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
