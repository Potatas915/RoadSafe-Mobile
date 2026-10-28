import 'package:flutter/material.dart';
import '../theme/roadsafe_theme.dart';

const _errorColor = Color(0xFFF87171);
const _blue = Color(0xFF60A5FA);
const _amber = Color(0xFFFBBF24);

/// The steps a report moves through, as the resident sees them.
const reportStages = ['Sent', 'Verified', 'Responding', 'Complete'];

/// Index into [reportStages], or -1 when the status is outside the normal path
/// (for example a rejected report).
int reportStage(String status) {
  switch (status) {
    case 'Submitted':
    case 'Under Review':
    case 'Additional Information Required':
      return 0;
    case 'Verified':
      return 1;
    case 'Assigned':
    case 'In Progress':
      return 2;
    case 'Resolved / Closed':
      return 3;
    default:
      return -1;
  }
}

bool isResolvedStatus(String status) => status == 'Resolved / Closed';
bool isClosedOutStatus(String status) =>
    status == 'Resolved / Closed' || status == 'Rejected';

Color reportStatusColor(String status) {
  switch (status) {
    case 'Additional Information Required':
    case 'Rejected':
      return _errorColor;
    case 'Verified':
    case 'In Progress':
      return _blue;
    case 'Assigned':
      return RoadSafeColors.orange;
    case 'Resolved / Closed':
      return RoadSafeColors.green;
    case 'Submitted':
    case 'Under Review':
      return _amber;
    default:
      return RoadSafeColors.muted;
  }
}

String reportStatusLabel(String status) =>
    status == 'Additional Information Required' ? 'Needs your reply' : status;

class ReportStatusChip extends StatelessWidget {
  const ReportStatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final tint = reportStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Text(
        reportStatusLabel(status),
        style: TextStyle(
          color: tint,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Response activity starts on assignment and ends at completion.
class ReportProgress extends StatelessWidget {
  const ReportProgress({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final stage = reportStage(status);
    if (stage < 0) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < reportStages.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: i == reportStages.length - 1 ? 0 : 4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (i == stage && i == 2 && !MediaQuery.disableAnimationsOf(context))
                    const Directionality(
                      textDirection: TextDirection.ltr,
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        color: RoadSafeColors.orange,
                        backgroundColor: RoadSafeColors.border,
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                        semanticsLabel: 'Enforcer responding',
                      ),
                    )
                  else Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: i <= stage
                          ? (i == stage && stage == reportStages.length - 1
                                ? RoadSafeColors.green
                                : RoadSafeColors.orange)
                          : RoadSafeColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reportStages[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: i == stage ? FontWeight.w800 : FontWeight.w500,
                      color: i == stage
                          ? Colors.white
                          : (i < stage
                                ? RoadSafeColors.muted
                                : RoadSafeColors.muted.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
