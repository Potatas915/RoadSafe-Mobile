import 'package:flutter/material.dart';
import '../theme/roadsafe_theme.dart';
import 'report_screen.dart';
import '../backend/report_tracking.dart';

/// Public landing page. Verification and dispatch belong to the web manager.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _brand(),
                  const SizedBox(height: 36),
                  const Text(
                    'HERE FOR SAFER ROADS',
                    style: TextStyle(
                      color: RoadSafeColors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A little action.\nA safer community.',
                    style: TextStyle(
                      fontSize: 32,
                      height: 1.15,
                      letterSpacing: -1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Help the RoadSafe team know where help is needed.',
                    style: TextStyle(
                      color: RoadSafeColors.muted,
                      height: 1.6,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _reportCard(context),
                  const SizedBox(height: 28),
                  _safetyNote(),
                  const SizedBox(height: 32),
                  const Text(
                    'Your reports',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  const MyReportsPreview(),
                  const SizedBox(height: 32),
                  const Text(
                    'Every report has a next step',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 18),
                  _workflowItem(
                    Icons.add_location_alt_outlined,
                    'You report',
                    'Share the accident details and location.',
                  ),
                  _workflowItem(
                    Icons.fact_check_outlined,
                    'The team verifies',
                    'Authorized personnel review the information.',
                  ),
                  _workflowItem(
                    Icons.support_agent,
                    'Help is coordinated',
                    'The team arranges a response when needed.',
                    last: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand() => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RoadSafe',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Together, we look out for each other.',
              style: TextStyle(color: RoadSafeColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _reportCard(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB83D0B), Color(0xFF8C2F0B)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: RoadSafeColors.orange.withValues(alpha: 0.4)),
      boxShadow: [
        BoxShadow(
          color: RoadSafeColors.orange.withValues(alpha: 0.08),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.car_crash_outlined,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Witnessed an accident?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Let the team know. Start with what you saw, from a safe place.',
          style: TextStyle(color: Color(0xFFFFE4D5), fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('report-accident'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF9A3412),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ReportScreen()),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'Report an Accident',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                SizedBox(width: 10),
                Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _safetyNote() => const Row(
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
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _workflowItem(
    IconData icon,
    String title,
    String description, {
    bool last = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: RoadSafeColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RoadSafeColors.border),
          ),
          child: Icon(icon, color: RoadSafeColors.orange, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(
                  color: RoadSafeColors.muted,
                  fontSize: 12,
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
