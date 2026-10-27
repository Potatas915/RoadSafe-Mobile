import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../widgets/evidence_section.dart';
import 'username.dart';
import 'categories.dart';
import 'reporter_validation.dart';

Map<String, dynamic> buildSubmissionParams({
  required String submissionId,
  required String category,
  required String description,
  required double latitude,
  required double longitude,
  required DateTime occurredAt,
  required String injuries,
  String? name,
  String? contact,
  String vehicleStatus = 'unknown',
  List<Map<String, dynamic>> vehicles = const [],
  int? injuredCount,
  int? fatalityCount,
}) {
  String? optional(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
  return {
    'p_submission_id': submissionId,
    'p_category': category,
    'p_description': description.trim(),
    'p_latitude': latitude,
    'p_longitude': longitude,
    'p_occurred_at': occurredAt.toUtc().toIso8601String(),
    'p_injuries': injuries,
    'p_name': optional(name),
    'p_contact': optional(contact),
    'p_vehicle_status': vehicleStatus,
    'p_vehicles': vehicles,
    'p_injured_count': injuredCount,
    'p_fatality_count': fatalityCount,
  };
}

class RoadSafeBackend extends ChangeNotifier {
  RoadSafeBackend({SupabaseClient? client}) : _client = client;
  static final instance = RoadSafeBackend();
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _authSubscription;
  String? initializationError;
  bool get ready => _client != null;
  bool get signedIn => _client?.auth.currentUser != null;
  String? get userId => _client?.auth.currentUser?.id;
  String? get username {
    final user = _client?.auth.currentUser;
    return user?.userMetadata?['name'] as String? ??
        user?.userMetadata?['username'] as String? ??
        user?.email?.split('@').first;
  }

  SupabaseClient get client =>
      _client ??
      (throw StateError(
        'Backend connection is unavailable. Restart the app and try again.',
      ));

  Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: 'https://ideyzteydxkfmpphzigz.supabase.co',
        ),
        publishableKey: const String.fromEnvironment(
          'SUPABASE_PUBLISHABLE_KEY',
          defaultValue: 'sb_publishable_CYluBTHUSTJbgxJqo8_o1g_Yf4-q0TY',
        ),
      );
      _client = Supabase.instance.client;
      _authSubscription = client.auth.onAuthStateChange.listen(
        (_) => notifyListeners(),
      );
    } catch (_) {
      initializationError =
          'Could not initialize the backend. Restart the app to retry.';
    }
    notifyListeners();
  }

  Future<void> signIn(String username, String password) async {
    String identity;
    try {
      identity = loginIdentity(username);
    } on FormatException catch (error) {
      throw AuthException(error.message);
    }
    await client.auth.signInWithPassword(email: identity, password: password);
  }

  Future<bool> signUp(
    String email,
    String password, {
    required String fullName,
    String? username,
    String accountType = 'Public',
    String? stationId,
  }) async {
    final canonical = email.trim().toLowerCase();
    final name = fullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final nameError = validateReporterName(name);
    if (nameError != null) throw AuthException(nameError);
    if (!validAccountEmail(canonical)) throw const AuthException('Enter a valid email address.');
    if (username != null && !validUsername(username)) {
      throw const AuthException('Use 3–24 letters, numbers or underscores; start with a letter.');
    }
    try {
      await client.functions.invoke(
        'register-username',
        body: {
          'email': canonical,
          'fullName': name,
          if (username != null) 'username': normalizeUsername(username),
          'password': password,
          'accountType': accountType,
          if (accountType == 'Officer') 'stationId': stationId,
        },
      );
    } on FunctionException catch (error) {
      final details = error.details;
      throw AuthException(
        details is Map && details['message'] is String
            ? details['message'] as String
            : 'Could not create the account. Please try again.',
      );
    }
    // Registration has succeeded. A connection interruption during automatic
    // sign-in must not tell the user that the account was never created.
    try {
      await signIn(username == null ? canonical : normalizeUsername(username), password);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() => client.auth.signOut();
  Future<String> submit(Map<String, dynamic> params) async {
    if (!signedIn) throw StateError('Sign in before sending your report.');
    return (await client.rpc('submit_accident_report', params: params))
        as String;
  }

  Future<void> uploadEvidence(
    String reportId,
    EvidencePhoto photo,
    String evidenceId,
  ) async {
    final uid = userId ?? (throw StateError('Sign in to upload evidence.'));
    final name = photo.file.name;
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : 'jpg';
    final mime = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => 'image/jpeg',
    };
    final path = '$uid/$reportId/$evidenceId.$extension';
    try {
      await client.storage
          .from('accident-evidence')
          .uploadBinary(
            path,
            photo.bytes,
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
    } on StorageException catch (error) {
      // The previous upload may have succeeded before its response was lost.
      if (!(error.statusCode == '409' ||
          error.message.toLowerCase().contains('already exists') ||
          error.message.toLowerCase().contains('duplicate'))) {
        rethrow;
      }
    }
    await client.rpc(
      'register_report_evidence',
      params: {
        'p_id': reportId,
        'p_evidence_id': evidenceId,
        'p_file_name': name,
        'p_path': path,
      },
    );
  }

  Future<List<AccidentCategory>> categories() async {
    return parseCategories(
      await client.from('accident_categories').select('id,label,enabled'),
    );
  }

  Future<List<Map<String, dynamic>>> reports({bool ownOnly = true}) async {
    final feed = Map<String, dynamic>.from(await client.rpc('get_report_feed'));
    final catalog = await categories();
    return (feed['data'] as List).where((item) => !ownOnly || item['reporter']['userId'] == userId).map((item) {
      final report = Map<String, dynamic>.from(item as Map);
      report['categoryLabel'] =
          catalog
              .where((row) => row.id == report['categoryId'])
              .firstOrNull
              ?.label ??
          report['categoryId'];
      return report;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final rows = await client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> markRead(int id) =>
      client.rpc('mark_notification_read', params: {'p_id': id});
  Future<void> clarify(String id, String message) => client.rpc(
    'respond_to_clarification',
    params: {'p_id': id, 'p_message': message},
  );
  Future<String> evidenceUrl(String path) =>
      client.storage.from('accident-evidence').createSignedUrl(path, 600);

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

class SubmissionDraft {
  final id = const Uuid().v4();
  String? reportId;
  final evidenceIds = <String, String>{};
  final uploaded = <String>{};
  String evidenceId(EvidencePhoto photo) =>
      evidenceIds.putIfAbsent(photo.file.path, () => const Uuid().v4());
}
