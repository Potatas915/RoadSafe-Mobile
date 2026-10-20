import 'backend.dart';

bool canVerifyCase(Map<String, dynamic> report, String? uid) =>
    uid != null &&
    report['reporter']['userId'] != uid &&
    report['isDuplicate'] != true &&
    report['assignedOfficerId'] == null &&
    [
      'Submitted',
      'Under Review',
      'Additional Information Required',
    ].contains(report['status']);

bool isOwnActiveCase(Map<String, dynamic> report, String? uid) =>
    uid != null &&
    report['assignedOfficerId'] == uid &&
    ['Assigned', 'In Progress'].contains(report['status']);

List<String> enforcerStatuses(Map<String, dynamic> report, String? uid) {
  if (canVerifyCase(report, uid)) return ['Verified'];
  if (!isOwnActiveCase(report, uid)) return [];
  return report['status'] == 'Assigned'
      ? ['Assigned', 'In Progress']
      : ['In Progress', 'Resolved / Closed'];
}

class EnforcerBackend {
  EnforcerBackend(this.backend);
  final RoadSafeBackend backend;
  Future<Map<String, dynamic>?> medicalRecommendation(String reportId) async {
    final result = await backend.client.rpc(
      'get_medical_recommendation',
      params: {'p_id': reportId},
    );
    return result == null ? null : Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> context() async => Map<String, dynamic>.from(
    await backend.client.rpc('get_enforcer_context'),
  );
  Future<void> duty(String station, bool onDuty) => backend.client.rpc(
    'set_enforcer_duty',
    params: {'p_station': station, 'p_on_duty': onDuty},
  );
  Future<void> update(
    Map<String, dynamic> report,
    String status,
    String remarks,
  ) async {
    if (!enforcerStatuses(report, backend.userId).contains(status)) {
      throw StateError('This action is not available for this case.');
    }
    await backend.client.rpc(
      'update_accident_report',
      params: {
        'p_id': report['id'],
        'p_status': status,
        'p_officer': report['assignedOfficerId'],
        'p_remarks': remarks.trim(),
        'p_reason': null,
        'p_version': report['version'],
      },
    );
  }
}
