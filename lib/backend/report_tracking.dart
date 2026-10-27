import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/roadsafe_theme.dart';
import '../widgets/report_progress.dart';
import 'backend.dart';
import 'format.dart';

const _errorColor = Color(0xFFF87171);

/// "My reports": every report the resident sent, how far each has come, and
/// updates from the team.
class ReportTrackingScreen extends StatefulWidget {
  const ReportTrackingScreen({super.key, this.reportId, this.backend});
  final String? reportId;
  final RoadSafeBackend? backend;
  @override
  State<ReportTrackingScreen> createState() => _ReportTrackingScreenState();
}

class _ReportTrackingScreenState extends State<ReportTrackingScreen> {
  late final backend = widget.backend ?? RoadSafeBackend.instance;
  final _savingUpdates = <int>{};
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _updates = [];
  Timer? _timer;
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  int _filter = 0; // 0 all, 1 open, 2 resolved

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
      if (mounted) {
        setState(() {
          _busy = false;
          _loaded = true;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    final all = _reports
        .where(
          (report) =>
              widget.reportId == null || report['id'] == widget.reportId,
        )
        .toList();
    final open = all
        .where((r) => !isClosedOutStatus('${r['status']}'))
        .toList();
    final resolved = all.where((r) => isResolvedStatus('${r['status']}')).toList();
    final shown = _filter == 1
        ? open
        : _filter == 2
        ? resolved
        : all;
    final unread = _updates.where((u) => u['read_at'] == null).length;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('back'),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('My reports'),
          actions: [
            IconButton(
              tooltip: 'Refresh reports',
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            indicatorColor: RoadSafeColors.orange,
            labelColor: Colors.white,
            unselectedLabelColor: RoadSafeColors.muted,
            dividerColor: RoadSafeColors.border,
            tabs: [
              Tab(
                child: _tabLabel(
                  Icons.assignment_outlined,
                  'Reports',
                  all.length,
                ),
              ),
              Tab(
                child: _tabLabel(
                  Icons.notifications_none,
                  'Updates',
                  unread,
                  highlight: true,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _banner(_error!),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _reportsTab(all, open, resolved, shown),
                  _updatesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabLabel(
    IconData icon,
    String label,
    int count, {
    bool highlight = false,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      if (count > 0) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: highlight
                ? RoadSafeColors.orange
                : RoadSafeColors.orange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: highlight ? Colors.white : RoadSafeColors.orange,
            ),
          ),
        ),
      ],
    ],
  );

  Widget _banner(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _errorColor.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _errorColor.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 18, color: _errorColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.5)),
        ),
      ],
    ),
  );

  // ───────────────────────── Reports tab ─────────────────────────

  Widget _reportsTab(
    List<Map<String, dynamic>> all,
    List<Map<String, dynamic>> open,
    List<Map<String, dynamic>> resolved,
    List<Map<String, dynamic>> shown,
  ) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (all.isNotEmpty && widget.reportId == null) ...[
          Row(
            children: [
              _filterTile('All', all.length, 0, Icons.layers_outlined),
              const SizedBox(width: 10),
              _filterTile('Open', open.length, 1, Icons.timelapse),
              const SizedBox(width: 10),
              _filterTile(
                'Resolved',
                resolved.length,
                2,
                Icons.check_circle_outline,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (!_loaded && all.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (shown.isEmpty)
          _empty(
            Icons.assignment_outlined,
            all.isEmpty ? 'No reports yet' : 'Nothing here',
            all.isEmpty
                ? 'When you report an accident, you can follow every step of it here. Go back and tap Report an Incident to start.'
                : 'No reports match this filter.',
          )
        else
          ...shown.map(_reportCard),
      ],
    ),
  );

  Widget _filterTile(String label, int count, int value, IconData icon) {
    final selected = _filter == value;
    return Expanded(
      child: Material(
        color: selected
            ? RoadSafeColors.orange.withValues(alpha: 0.14)
            : RoadSafeColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _filter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? RoadSafeColors.orange
                    : RoadSafeColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? RoadSafeColors.orange
                      : RoadSafeColors.muted,
                ),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : RoadSafeColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(IconData icon, String title, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 12),
    child: Column(
      children: [
        Icon(icon, size: 44, color: RoadSafeColors.muted),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: RoadSafeColors.muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    ),
  );

  String _vehicles(Map<String, dynamic> report) {
    if (report['vehicleStatus'] == 'not_applicable') return 'No vehicles';
    final list = (report['vehicles'] as List?) ?? const [];
    if (list.isEmpty) return 'Not reported';
    return list.map((v) => '${v['count']} × ${v['type']}').join(', ');
  }

  Widget _reportCard(Map<String, dynamic> report) {
    final status = '${report['status']}';
    final needsReply = status == 'Additional Information Required';
    final remarks = '${report['officialRemarks'] ?? ''}'.trim();
    final evidence = (report['evidence'] as List?) ?? const [];
    final events = (report['events'] as List?) ?? const [];
    final category =
        report['categoryLabel'] as String? ??
        report['categoryId'] as String? ??
        'Accident';
    final when = report['occurredAt'] ?? report['createdAt'];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: RoadSafeColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: needsReply
              ? _errorColor.withValues(alpha: 0.5)
              : RoadSafeColors.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 4, color: reportStatusColor(status)),
          Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('report-${report['id']}'),
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: RoadSafeColors.muted,
          collapsedIconColor: RoadSafeColors.muted,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: RoadSafeColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.car_crash_outlined,
                  size: 20,
                  color: RoadSafeColors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (when != null)
                      Text(
                        relativeWhen(when),
                        style: const TextStyle(
                          color: RoadSafeColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ReportStatusChip(status),
                ),
                const SizedBox(height: 12),
                ReportProgress(status: status),
                const SizedBox(height: 4),
              ],
            ),
          ),
          children: [
            if (needsReply)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _errorColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The team needs more information about this report.',
                      style: TextStyle(fontSize: 12.5, height: 1.5),
                    ),
                    TextButton(
                      onPressed: () => _clarify(report['id'] as String),
                      child: const Text('Provide additional information'),
                    ),
                  ],
                ),
              ),
            _detail('What you reported', '${report['description'] ?? ''}'),
            _detail('Vehicles', _vehicles(report)),
            _detail(
              'People hurt',
              'Injured: ${report['injuries']?['injuredCount'] ?? 'Unknown'} · Fatalities: ${report['injuries']?['fatalityCount'] ?? 'Unknown'}',
            ),
            if (remarks.isNotEmpty)
              _detail('Official remarks (includes earlier updates)', remarks),
            if (report['isDuplicate'] == true)
              _detail('Note', 'Marked as a duplicate report'),
            if (report['rejectionReason'] != null)
              _detail('Reason', '${report['rejectionReason']}'),
            if (evidence.isNotEmpty) ...[
              _EvidenceCarousel(
                key: ValueKey('evidence-${report['id']}'),
                paths: [
                  for (final file in evidence)
                    if (file is Map && file['storagePath'] is String)
                      file['storagePath'] as String,
                ],
                loadUrl: backend.evidenceUrl,
              ),
              const SizedBox(height: 12),
            ],
            if (events.isNotEmpty) ...[
              const Divider(color: RoadSafeColors.border),
              const SizedBox(height: 8),
              const Text(
                'HISTORY',
                style: TextStyle(
                  color: RoadSafeColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < events.length; i++)
                _eventRow(events[i], last: i == events.length - 1),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Reference: ${report['id']}',
                style: const TextStyle(
                  color: RoadSafeColors.muted,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: RoadSafeColors.muted, fontSize: 11.5),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 13.5, height: 1.5)),
      ],
    ),
  );

  Widget _eventRow(Object? event, {required bool last}) {
    final data = event is Map ? event : const {};
    final title = data['type'] == 'facts_corrected'
        ? 'Incident facts corrected'
        : '${data['status'] ?? data['type'] ?? 'Update'}';
    final message = reportEventMessage(data);
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
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: RoadSafeColors.orange,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 1.5, color: RoadSafeColors.border),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    formatWhen(data['createdAt']),
                    style: const TextStyle(
                      color: RoadSafeColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: const TextStyle(fontSize: 12.5, height: 1.5),
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

  // ───────────────────────── Updates tab ─────────────────────────

  Future<void> _setUpdateRead(Map<String, dynamic> update, bool read) async {
    final id = update['id'] as int;
    if (_savingUpdates.contains(id)) return;
    setState(() => _savingUpdates.add(id));
    try {
      await backend.setNotificationRead(id, read);
      await _refresh();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not mark the update as ${read ? 'read' : 'unread'}. Try again.');
      }
    } finally {
      if (mounted) setState(() => _savingUpdates.remove(id));
    }
  }

  Widget _updatesTab() => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (_loaded && _updates.isEmpty)
          _empty(
            Icons.notifications_none,
            'No updates yet',
            'Messages from the RoadSafe team about your reports will show up here.',
          ),
        ..._updates.map((update) {
          final unread = update['read_at'] == null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: RoadSafeColors.card,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _savingUpdates.contains(update['id']) ? null : () => _setUpdateRead(update, true),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: unread
                          ? RoadSafeColors.orange.withValues(alpha: 0.55)
                          : RoadSafeColors.border,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        unread
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_none,
                        color: unread
                            ? RoadSafeColors.orange
                            : RoadSafeColors.muted,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              update['message'] as String,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.45,
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              relativeWhen(update['created_at']),
                              style: const TextStyle(
                                color: RoadSafeColors.muted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 104,
                        child: TextButton(
                          onPressed: _savingUpdates.contains(update['id'])
                              ? null
                              : () => _setUpdateRead(update, unread),
                          child: Text(unread ? 'Mark as read' : 'Mark as unread', textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    ),
  );
}

/// Swipeable photo strip for a report. With more than one photo it loops
/// endlessly in both directions; tapping opens a full-screen viewer.
class _EvidenceCarousel extends StatefulWidget {
  const _EvidenceCarousel({
    super.key,
    required this.paths,
    required this.loadUrl,
  });
  final List<String> paths;
  final Future<String> Function(String path) loadUrl;

  @override
  State<_EvidenceCarousel> createState() => _EvidenceCarouselState();
}

class _EvidenceCarouselState extends State<_EvidenceCarousel> {
  static const _loopStart = 5000;
  final Map<String, Future<String>> _urls = {};
  late final PageController _controller;
  int _page = 0;

  int get _count => widget.paths.length;
  bool get _loops => _count > 1;

  @override
  void initState() {
    super.initState();
    // Start in the middle so the user can swipe either way forever.
    _controller = PageController(
      keepPage: false,
      initialPage: _loops ? _loopStart * _count : 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String> _url(String path) =>
      _urls.putIfAbsent(path, () => widget.loadUrl(path));

  Widget _photo(String path, {BoxFit fit = BoxFit.cover}) => FutureBuilder<String>(
    future: _url(path),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Photo could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(color: RoadSafeColors.muted, fontSize: 12.5),
            ),
          ),
        );
      }
      final url = snapshot.data;
      if (url == null) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      return Image.network(
        url,
        fit: fit,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image_outlined, color: RoadSafeColors.muted),
        ),
      );
    },
  );

  void _open(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PhotoViewer(
          paths: widget.paths,
          initial: index,
          photo: (path) => _photo(path, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _count == 1 ? 'PHOTO' : 'PHOTOS · $_count',
          style: const TextStyle(
            color: RoadSafeColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 210,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: RoadSafeColors.border,
                    child: PageView.builder(
                      key: const Key('evidence-pages'),
                      controller: _controller,
                      itemCount: _loops ? null : 1,
                      onPageChanged: (i) => setState(() => _page = i % _count),
                      itemBuilder: (context, i) {
                        final index = i % _count;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _open(index),
                          child: _photo(widget.paths[index]),
                        );
                      },
                    ),
                  ),
                ),
                if (_loops)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 10,
                    child: IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _count; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _page ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == _page
                                    ? RoadSafeColors.orange
                                    : Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.open_in_full,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_loops)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Swipe to see more · tap to enlarge',
              style: TextStyle(color: RoadSafeColors.muted, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

/// Full-screen, swipeable (and endlessly looping) photo viewer.
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({
    required this.paths,
    required this.initial,
    required this.photo,
  });
  final List<String> paths;
  final int initial;
  final Widget Function(String path) photo;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _controller;
  late int _page = widget.initial;
  int get _count => widget.paths.length;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      keepPage: false,
      initialPage: _count > 1 ? 5000 * _count + widget.initial : 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      title: Text(_count > 1 ? '${_page + 1} / $_count' : 'Photo'),
      leading: IconButton(
        tooltip: 'Close photo',
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ),
    body: PageView.builder(
      controller: _controller,
      itemCount: _count > 1 ? null : 1,
      onPageChanged: (i) => setState(() => _page = i % _count),
      itemBuilder: (context, i) => InteractiveViewer(
        child: Center(child: widget.photo(widget.paths[i % _count])),
      ),
    ),
  );
}
