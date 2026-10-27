import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/roadsafe_theme.dart';
import '../widgets/roadsafe_logo.dart';
import '../backend/account_screen.dart';
import '../backend/backend.dart';
import '../backend/format.dart';
import '../widgets/report_progress.dart';
import 'my_reports_screen.dart';
import 'report_screen.dart';

/// Landing page: a branded hero on top and a "Get Started" section below.
///
/// Guests choose how to continue (resident or traffic enforcer) or sign up.
/// Signed-in residents go straight to reporting or to their reports.
/// Verification and dispatch belong to the web manager.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.backend});

  @visibleForTesting
  final RoadSafeBackend? backend;

  @override
  Widget build(BuildContext context) {
    final session = backend ?? RoadSafeBackend.instance;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.signedIn) return _Dashboard(session: session);
        return Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Hero(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: _guest(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _footer(Widget? top) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 16),
    child: SafeArea(
      top: false,
      child: Column(
        children: [
          if (top != null) ...[top, const SizedBox(height: 12)],
          const Text(
            'In immediate danger? Contact local emergency services first. A report does not guarantee an emergency response.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RoadSafeColors.muted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: RoadSafeColors.border, height: 1),
          const SizedBox(height: 12),
          const Text(
            'Community Accident Reporting System',
            style: TextStyle(color: RoadSafeColors.muted, fontSize: 11),
          ),
        ],
      ),
    ),
  );

  Widget _guest(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Highlights(),
      const SizedBox(height: 30),
      const Text(
        'GET STARTED',
        style: TextStyle(
          color: RoadSafeColors.orange,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'How would you like to continue?',
        style: TextStyle(
          fontSize: 22,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      const SizedBox(height: 16),
      _RoleCard(
        key: const Key('sign-in'),
        icon: Icons.person_outline,
        title: 'Resident Login',
        caption: 'Report accidents & track your reports',
        highlighted: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<bool>(
            builder: (_) => const AccountScreen(direct: true),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _RoleCard(
        key: const Key('enforcer-sign-in'),
        icon: Icons.badge_outlined,
        title: 'Enforcer Login',
        caption: 'Respond to cases & update status',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<bool>(
            builder: (_) => const AccountScreen(enforcer: true),
          ),
        ),
      ),
      const SizedBox(height: 22),
      Row(
        children: const [
          Expanded(child: Divider(color: RoadSafeColors.border)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'New here?',
              style: TextStyle(color: RoadSafeColors.muted, fontSize: 12.5),
            ),
          ),
          Expanded(child: Divider(color: RoadSafeColors.border)),
        ],
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        key: const Key('sign-up'),
        style: OutlinedButton.styleFrom(
          foregroundColor: RoadSafeColors.orange,
          side: const BorderSide(color: RoadSafeColors.orange),
          minimumSize: const Size(48, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<bool>(
            builder: (_) =>
                const AccountScreen(registration: true, direct: true),
          ),
        ),
        icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
        label: const Text(
          'Sign Up',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      _footer(null),
    ],
  );
}

/// Dark, road-themed top section: soft orange glow, a winding road with a
/// dashed centre line, the logo and a short headline.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
    child: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2540), Color(0xFF0B0F19)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _RoadPainter())),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const RoadSafeLogo(size: 52),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: RoadSafeColors.orange.withValues(
                                alpha: 0.16,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: RoadSafeColors.orange.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Accident Reporting System',
                              style: TextStyle(
                                color: RoadSafeColors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 70),
                      const Text(
                        'See something?\nReport it.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Your report helps make our roads safer. Residents report, enforcers respond — all in one place.',
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Orange glow and a curved road with a dashed centre line.
class _RoadPainter extends CustomPainter {
  const _RoadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawCircle(
      Offset(w * 0.92, h * 0.12),
      w * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            RoadSafeColors.orange.withValues(alpha: 0.35),
            RoadSafeColors.orange.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(w * 0.92, h * 0.12), radius: w * 0.55),
        ),
    );
    final road = Path()
      ..moveTo(w * 0.05, h * 0.62)
      ..cubicTo(w * 0.35, h * 0.38, w * 0.55, h * 0.95, w * 1.05, h * 0.55);
    canvas.drawPath(
      road,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 46
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.05),
    );
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = RoadSafeColors.orange.withValues(alpha: 0.7);
    for (final metric in road.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 14), dash);
        d += 28;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Three short selling points shown under the hero.
class _Highlights extends StatelessWidget {
  const _Highlights();

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Highlight(Icons.bolt_outlined, 'Quick reports'),
      _Highlight(Icons.timeline_outlined, 'Live progress'),
      _Highlight(Icons.verified_user_outlined, 'Verified officers'),
    ],
  );
}

class _Highlight extends StatelessWidget {
  const _Highlight(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: RoadSafeColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: RoadSafeColors.border),
          ),
          child: Icon(icon, color: RoadSafeColors.orange, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: RoadSafeColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// Large tappable card for a way to continue (resident or enforcer).
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.caption,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String caption;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: highlighted
        ? RoadSafeColors.orange.withValues(alpha: 0.10)
        : RoadSafeColors.card,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: highlighted
                ? RoadSafeColors.orange.withValues(alpha: 0.55)
                : RoadSafeColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: highlighted
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF97316), Color(0xFFD9490B)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      ),
                borderRadius: BorderRadius.circular(16),
                border: highlighted
                    ? null
                    : Border.all(color: RoadSafeColors.border),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    caption,
                    style: const TextStyle(
                      color: RoadSafeColors.muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: RoadSafeColors.muted),
          ],
        ),
      ),
    ),
  );
}

/// Home for signed-in residents: a dashboard rather than a landing page, with
/// the two main actions, the latest report's progress and a quick summary.
class _Dashboard extends StatefulWidget {
  const _Dashboard({required this.session});
  final RoadSafeBackend session;

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  RoadSafeBackend get session => widget.session;
  List<Map<String, dynamic>> _reports = [];
  Timer? _timer;
  bool _loaded = false;
  bool _failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (session.ready) {
      _refresh();
      _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
    }
  }

  @override
  void dispose() {
    _request++;
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final request = ++_request;
    try {
      final reports = await session.reports();
      if (mounted && request == _request) {
        setState(() {
          _reports = reports;
          _loaded = true;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _loaded = true;
          _failed = true;
        });
      }
    }
  }

  DateTime _stamp(Map<String, dynamic> report) =>
      DateTime.tryParse(
        '${report['createdAt'] ?? report['submittedAt'] ?? report['occurredAt']}',
      ) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted && session.ready) await _refresh();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    return hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = session.username;
    final open = _reports
        .where((r) => !isClosedOutStatus('${r['status']}'))
        .length;
    final resolved = _reports
        .where((r) => isResolvedStatus('${r['status']}'))
        .length;
    final latest = _reports.isEmpty
        ? null
        : _reports.reduce((a, b) => _stamp(b).isAfter(_stamp(a)) ? b : a);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(name),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionTile(
                              key: const Key('report-accident'),
                              icon: Icons.add_a_photo_outlined,
                              title: 'Report an Incident',
                              caption: 'Tell us what happened and where',
                              colors: const [
                                Color(0xFFF97316),
                                Color(0xFFC2410C),
                              ],
                              onTap: () => _open(const ReportScreen()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionTile(
                              key: const Key('my-reports'),
                              icon: Icons.receipt_long_outlined,
                              title: 'My reports',
                              caption: 'Follow progress and updates',
                              badge: open,
                              colors: const [
                                Color(0xFF1E293B),
                                Color(0xFF0F172A),
                              ],
                              bordered: true,
                              onTap: () => _open(const MyReportsScreen()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      _sectionLabel('LATEST REPORT'),
                      const SizedBox(height: 10),
                      _latest(latest),
                      const SizedBox(height: 22),
                      _sectionLabel('AT A GLANCE'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _stat('All', _reports.length, Icons.layers_outlined),
                          const SizedBox(width: 10),
                          _stat('Open', open, Icons.timelapse),
                          const SizedBox(width: 10),
                          _stat(
                            'Resolved',
                            resolved,
                            Icons.check_circle_outline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _safety(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(String? name) => Row(
    children: [
      Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF97316), Color(0xFFC2410C)],
          ),
        ),
        child: Text(
          (name == null || name.isEmpty ? 'R' : name[0]).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting,
              style: const TextStyle(
                color: RoadSafeColors.muted,
                fontSize: 12.5,
              ),
            ),
            Text(
              name ?? 'there',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
      PopupMenuButton<String>(
        key: const Key('account-menu'),
        tooltip: 'Account',
        icon: const Icon(Icons.more_vert),
        color: RoadSafeColors.card,
        onSelected: (value) {
          if (value == 'sign-out') session.signOut();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            key: Key('sign-out'),
            value: 'sign-out',
            child: Row(
              children: [
                Icon(Icons.logout, size: 18),
                SizedBox(width: 10),
                Text('Sign out'),
              ],
            ),
          ),
        ],
      ),
    ],
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: RoadSafeColors.muted,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.4,
    ),
  );

  Widget _latest(Map<String, dynamic>? report) {
    if (report == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: RoadSafeColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: RoadSafeColors.border),
        ),
        child: Row(
          children: [
            Icon(
              _failed ? Icons.cloud_off_outlined : Icons.route_outlined,
              color: RoadSafeColors.muted,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _failed
                    ? 'Could not load your reports. Pull down to retry.'
                    : _loaded || !session.ready
                    ? 'No reports yet. When you report an accident, its progress shows up here.'
                    : 'Loading your reports…',
                style: const TextStyle(
                  color: RoadSafeColors.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final status = '${report['status']}';
    return Material(
      color: RoadSafeColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _open(const MyReportsScreen()),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: RoadSafeColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      report['categoryLabel'] as String? ?? 'Accident',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ReportStatusChip(status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                relativeWhen(
                  report['occurredAt'] ?? report['createdAt'],
                ),
                style: const TextStyle(
                  color: RoadSafeColors.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              ReportProgress(status: status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, int value, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RoadSafeColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RoadSafeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: RoadSafeColors.orange),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: const TextStyle(color: RoadSafeColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget _safety() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: RoadSafeColors.orange.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: RoadSafeColors.orange.withValues(alpha: 0.25)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.health_and_safety_outlined,
          color: RoadSafeColors.orange,
          size: 22,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stay safe first',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'In immediate danger? Contact local emergency services. A report does not guarantee an emergency response.',
                style: TextStyle(
                  color: RoadSafeColors.muted,
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Big square-ish action tile. Both main actions share this look so they read
/// as equals.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.caption,
    required this.colors,
    required this.onTap,
    this.badge = 0,
    this.bordered = false,
  });

  final IconData icon;
  final String title;
  final String caption;
  final List<Color> colors;
  final int badge;
  final bool bordered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(24),
    child: Ink(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(24),
        border: bordered
            ? Border.all(color: RoadSafeColors.orange.withValues(alpha: 0.45))
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 156,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    if (badge > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: RoadSafeColors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$badge open',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
