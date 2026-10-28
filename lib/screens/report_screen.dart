import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/roadsafe_theme.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../widgets/incident_location_picker.dart';
import '../widgets/evidence_section.dart';
import '../widgets/roadsafe_logo.dart';
import '../backend/backend.dart';
import '../backend/account_screen.dart';
import '../backend/categories.dart';
import '../backend/reporter_validation.dart';
import 'my_reports_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    this.locationPickerBuilder,
    this.categoryLoader,
    this.backend,
  });
  final RoadSafeBackend? backend;

  @visibleForTesting
  final Future<List<AccidentCategory>> Function()? categoryLoader;

  @visibleForTesting
  final Widget Function(
    LatLng? initialLocation,
    ValueChanged<LatLng?> onChanged,
  )?
  locationPickerBuilder;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final backend = widget.backend ?? RoadSafeBackend.instance;
  bool _loadingProfile = false;
  String? _profileUserId;
  final _evidence = EvidenceController();
  final _submission = SubmissionDraft();
  bool _sending = false;
  String? _submissionMessage;
  DateTime? _incidentAt;
  Map<String, dynamic>? _submittedParams;
  final _detailsKey = GlobalKey<FormState>();
  final _locationKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  LatLng? _confirmedLocation;
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _scroll = ScrollController();
  int _step = 0;
  String? _category;
  List<AccidentCategory> _catalog = defaultCategories;
  String? _categoryError;
  bool _loadingCategories = false;
  String _categoryLabel(String id) =>
      _catalog.firstWhere((row) => row.id == id).label;
  Future<void> _loadCategories() async {
    if (!backend.ready && widget.categoryLoader == null) {
      return;
    }
    setState(() {
      _loadingCategories = true;
    });
    try {
      final catalog =
          await (widget.categoryLoader?.call() ?? backend.categories());
      if (mounted) {
        setState(() {
          _catalog = catalog;
          _categoryError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _categoryError =
              'Could not load current categories. Check your connection and retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingCategories = false;
        });
      }
    }
  }

  String _injuries = 'Not sure';
  String _vehicleStatus = 'unknown';
  final Map<String, int> _vehicles = {};
  final _injuredCount = TextEditingController();
  final _fatalityCount = TextEditingController();
  static const _vehicleTypes = [
    'car',
    'motorcycle',
    'tricycle',
    'jeepney',
    'van',
    'bus',
    'truck',
    'bicycle',
    'other',
    'unknown',
  ];
  String get _injuryStatus => _injuries == 'No injuries'
      ? 'none'
      : _injuries == 'Someone is hurt'
      ? 'injured'
      : _injuries == 'Fatality reported'
      ? 'fatal'
      : 'unknown';
  String get _vehicleSummary => _vehicleStatus == 'unknown'
      ? 'Unknown'
      : _vehicleStatus == 'not_applicable'
      ? 'Not applicable'
      : _vehicles.entries.map((e) => '${e.value} × ${e.key}').join(', ');
  static const _categories = <String, (String, IconData)>{
    'collision': ('Collision', Icons.car_crash_outlined),
    'hit-and-run': ('Hit-and-run', Icons.directions_car_outlined),
    'rollover': ('Vehicle rollover', Icons.flip_camera_android_outlined),
    'pedestrian': ('Pedestrian accident', Icons.directions_walk),
    'other': ('Other accident', Icons.more_horiz),
  };

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _evidence.recoverLostPhotos();
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _description,
      _name,
      _contact,
      _injuredCount,
      _fatalityCount,
    ]) {
      controller.dispose();
    }
    _evidence.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _chooseIncidentTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _incidentAt ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_incidentAt ?? now),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (value.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The accident time cannot be in the future.'),
        ),
      );
      return;
    }
    setState(() => _incidentAt = value);
  }

  String _incidentTimeLabel() {
    if (_incidentAt == null) return 'Happening now';
    final local = MaterialLocalizations.of(context);
    return '${local.formatMediumDate(_incidentAt!)} · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(_incidentAt!))}';
  }

  Future<void> _sendReport() async {
    if (_sending || !backend.ready) return;
    if (!backend.signedIn) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AccountScreen()),
      );
      if (!mounted) return;
      setState(() {});
      if (!backend.signedIn) return;
    }
    setState(() {
      _sending = true;
      _submissionMessage = null;
    });
    try {
      if (_profileUserId != backend.userId) {
        throw StateError(
          'Your account changed. Return to location and review your profile again.',
        );
      }
      _submittedParams ??= buildSubmissionParams(
        submissionId: _submission.id,
        category: _category!,
        description: _description.text,
        latitude: _confirmedLocation!.latitude,
        longitude: _confirmedLocation!.longitude,
        occurredAt: _incidentAt ?? DateTime.now(),
        injuries: _injuryStatus,
        vehicleStatus: _vehicleStatus,
        vehicles: _vehicleStatus == 'known'
            ? _vehicles.entries
                  .map(
                    (e) => <String, dynamic>{'type': e.key, 'count': e.value},
                  )
                  .toList()
            : [],
        injuredCount: ['injured', 'fatal'].contains(_injuryStatus)
            ? int.tryParse(_injuredCount.text)
            : null,
        fatalityCount: _injuryStatus == 'fatal'
            ? int.tryParse(_fatalityCount.text)
            : null,
        name: _name.text,
        contact: _contact.text,
      );
      _submission.reportId ??= await backend.submit(_submittedParams!);
      for (final photo in _evidence.photos) {
        final id = _submission.evidenceId(photo);
        if (_submission.uploaded.contains(id)) continue;
        await backend.uploadEvidence(_submission.reportId!, photo, id);
        _submission.uploaded.add(id);
      }
      if (!mounted) return;
      final viewReports = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Report received'),
          content: Text(
            'Reference: ${_submission.reportId}\n\nYour report is saved and awaiting verification. You can follow its progress under My reports.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Done'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('View my reports'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (viewReports == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (_) => const MyReportsScreen()),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (error is PostgrestException &&
          error.message.startsWith('This category is unavailable.') &&
          _submission.reportId == null) {
        _submittedParams = null;
        await _loadCategories();
        if (mounted) _goTo(0);
      }
      if (error is PostgrestException &&
          error.message.startsWith(
            'Full name and contact number are required',
          ) &&
          _submission.reportId == null) {
        _submittedParams = null;
        if (mounted) _goTo(1);
      }
      if (mounted) {
        setState(
          () => _submissionMessage = _submission.reportId == null
              ? 'Could not send the report: $error. Retry with the same details; your submission reference prevents duplicates.'
              : 'Your report is saved (${_submission.reportId}), but some photos are not attached yet: $error. Retry photo upload below.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _continue() async {
    if (_evidence.busy || _loadingProfile) return;
    final valid = _step == 0
        ? _detailsKey.currentState!.validate()
        : _locationKey.currentState!.validate();
    if (!valid) return;
    if (_step == 1) {
      setState(() => _loadingProfile = true);
      try {
        if (!backend.signedIn) {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => AccountScreen(backend: backend)),
          );
          if (!mounted || !backend.signedIn) return;
        }
        final profile = await backend.reporterProfile();
        if (!mounted) return;
        final nameError = validateReporterName(profile['name']);
        final contactError = validateReporterContact(profile['contact']);
        if (nameError != null || contactError != null) {
          throw StateError(
            'Your profile needs a valid full name and mobile number. Update your account before reporting.',
          );
        }
        _name.text = profile['name']!;
        _contact.text = profile['contact']!;
        _profileUserId = backend.userId;
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load your profile: $error')),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _loadingProfile = false);
      }
    }
    if (mounted) _goTo(_step + 1);
  }

  Widget _countField(
    String label,
    TextEditingController controller,
    int minimum,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        helperText: 'Optional — leave blank if unknown',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return null;
        final count = int.tryParse(value);
        return !RegExp(r'^\d+$').hasMatch(value) ||
                count == null ||
                count < minimum ||
                count > 999
            ? 'Enter a whole number from $minimum to 999, or leave blank'
            : null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sending && _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_sending && _submittedParams == null && _step > 0) {
          _goTo(_step - 1);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _progress(),
                          const SizedBox(height: 28),
                          Text(
                            [
                              'Report an incident',
                              'Where did it happen?',
                              'Check your report',
                            ][_step],
                            style: const TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            [
                              'Tell us what happened. Your report helps the RoadSafe team assess the incident.',
                              'Place the pin where the accident happened, then confirm the location.',
                              'Make sure the details are accurate before sending them for review.',
                            ][_step],
                            style: const TextStyle(
                              color: RoadSafeColors.muted,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_step == 0) _details(),
                          if (_step == 1) _locationForm(),
                          if (_step == 2) _review(),
                          const SizedBox(height: 24),
                          _footer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoadSafeColors.border)),
    ),
    child: Row(
      children: [
        if (Navigator.of(context).canPop())
          IconButton(
            tooltip: 'Return home',
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
        const RoadSafeLogo(size: 44),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RoadSafe',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              Text(
                'Community accident reporting',
                style: TextStyle(fontSize: 11, color: RoadSafeColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _progress() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'STEP ${_step + 1} OF 3',
        style: const TextStyle(
          color: RoadSafeColors.orange,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: List.generate(
          3,
          (index) => Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
              decoration: BoxDecoration(
                color: index <= _step
                    ? RoadSafeColors.orange
                    : RoadSafeColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        ['Accident details', 'Accident location', 'Review'][_step],
        style: const TextStyle(fontSize: 12, color: RoadSafeColors.muted),
      ),
    ],
  );

  Widget _details() => Form(
    key: _detailsKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'What kind of accident?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            if (backend.ready || widget.categoryLoader != null)
              IconButton(
                tooltip: 'Refresh categories',
                visualDensity: VisualDensity.compact,
                onPressed: _loadingCategories ? null : _loadCategories,
                icon: const Icon(Icons.refresh, size: 20),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingCategories)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
        if (_categoryError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _categoryError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FormField<String>(
          validator: (_) => _loadingCategories || _categoryError != null
              ? 'Refresh categories before continuing'
              : _category == null
              ? 'Select an accident type'
              : !_catalog.any((row) => row.id == _category && row.enabled)
              ? 'Select an available accident type'
              : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._categories.entries
                  .where(
                    (entry) => _catalog.any(
                      (row) => row.id == entry.key && row.enabled,
                    ),
                  )
                  .map((entry) {
                    final selected = _category == entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: selected
                            ? RoadSafeColors.orange.withValues(alpha: 0.09)
                            : RoadSafeColors.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: selected
                                ? RoadSafeColors.orange
                                : RoadSafeColors.border,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Semantics(
                          selected: selected,
                          child: InkWell(
                            onTap: () {
                              setState(() => _category = entry.key);
                              field.didChange(entry.key);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    entry.value.$2,
                                    color: selected
                                        ? RoadSafeColors.orange
                                        : RoadSafeColors.muted,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      _categoryLabel(entry.key),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    selected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 20,
                                    color: selected
                                        ? RoadSafeColors.orange
                                        : RoadSafeColors.muted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    field.errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _label('When did it happen?'),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Happening now'),
              selected: _incidentAt == null,
              onSelected: (_) => setState(() => _incidentAt = null),
            ),
            TextButton.icon(
              onPressed: _chooseIncidentTime,
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(
                _incidentAt == null
                    ? 'Choose date & time'
                    : _incidentTimeLabel(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _label('Is anyone hurt?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                    'Not sure',
                    'No injuries',
                    'Someone is hurt',
                    'Fatality reported',
                  ]
                  .map(
                    (label) => ChoiceChip(
                      label: Text(label),
                      selected: _injuries == label,
                      onSelected: (_) => setState(() {
                        _injuries = label;
                        _injuredCount.clear();
                        _fatalityCount.clear();
                      }),
                      selectedColor: RoadSafeColors.orange.withValues(
                        alpha: 0.16,
                      ),
                      showCheckmark: true,
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 24),
        if (['injured', 'fatal'].contains(_injuryStatus))
          _countField(
            'Known injured count',
            _injuredCount,
            _injuryStatus == 'injured' ? 1 : 0,
          ),
        if (_injuryStatus == 'fatal')
          _countField('Known fatality count', _fatalityCount, 1),
        _label('Vehicles involved'),
        FormField<String>(
          validator: (_) => _vehicleStatus == 'known' && _vehicles.isEmpty
              ? 'Add at least one vehicle type and count'
              : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in const [
                    ('unknown', 'Not sure'),
                    ('known', 'I know the vehicles'),
                    ('not_applicable', 'No vehicles'),
                  ])
                    ChoiceChip(
                      key: Key('vehicle-status-${option.$1}'),
                      label: Text(option.$2),
                      selected: _vehicleStatus == option.$1,
                      selectedColor: RoadSafeColors.orange,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _vehicleStatus == option.$1
                            ? Colors.white
                            : null,
                      ),
                      showCheckmark: false,
                      onSelected: (_) =>
                          setState(() => _vehicleStatus = option.$1),
                    ),
                ],
              ),
              if (_vehicleStatus == 'known') ...[
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final type in _vehicleTypes)
                          SizedBox(width: width, child: _vehicleTile(type)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  _vehicles.isEmpty
                      ? 'Tap + on each vehicle type involved. Use "Unknown type" when you can count them but are unsure what they are.'
                      : 'Total: ${_vehicles.values.fold<int>(0, (a, b) => a + b)} vehicle${_vehicles.values.fold<int>(0, (a, b) => a + b) == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: _vehicles.isEmpty
                        ? RoadSafeColors.muted
                        : RoadSafeColors.orange,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: _vehicles.isEmpty
                        ? FontWeight.w400
                        : FontWeight.w700,
                  ),
                ),
              ],
              if (field.hasError &&
                  _vehicleStatus == 'known' &&
                  _vehicles.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    field.errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _label('What happened?'),
        TextFormField(
          key: const Key('description'),
          controller: _description,
          minLines: 4,
          maxLines: 7,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Describe the vehicles involved and what you observed.',
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Describe the accident'
              : null,
        ),
        const SizedBox(height: 20),
        EvidenceSection(controller: _evidence),
        const SizedBox(height: 20),
        _notice(
          Icons.health_and_safety_outlined,
          'Your safety comes first',
          'Report only when you are in a safe place. Do not approach traffic to collect details.',
        ),
      ],
    ),
  );

  Widget _locationForm() => Form(
    key: _locationKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Accident location'),
        FormField<LatLng>(
          initialValue: _confirmedLocation,
          validator: (_) => _confirmedLocation == null
              ? 'Pin and confirm the accident location'
              : null,
          builder: (field) {
            void onChanged(LatLng? point) {
              setState(() => _confirmedLocation = point);
              field.didChange(point);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.locationPickerBuilder?.call(
                      _confirmedLocation,
                      onChanged,
                    ) ??
                    IncidentLocationPicker(
                      initialLocation: _confirmedLocation,
                      onChanged: onChanged,
                    ),
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      field.errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _review() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: RoadSafeColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: RoadSafeColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_outlined, color: RoadSafeColors.orange),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Accident report',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _summary('Accident type', _categoryLabel(_category!)),
            _summary('Incident time', _incidentTimeLabel()),
            _summary('Injuries', _injuries),
            if (['injured', 'fatal'].contains(_injuryStatus))
              _summary(
                'Injured count',
                _injuredCount.text.isEmpty ? 'Unknown' : _injuredCount.text,
              ),
            if (_injuryStatus == 'fatal')
              _summary(
                'Fatality count',
                _fatalityCount.text.isEmpty ? 'Unknown' : _fatalityCount.text,
              ),
            _summary('Vehicles', _vehicleSummary),
            _summary('What happened', _description.text.trim()),
            _summary(
              'Accident coordinates',
              '${_confirmedLocation!.latitude.toStringAsFixed(6)}, ${_confirmedLocation!.longitude.toStringAsFixed(6)}',
            ),
            _summary(
              'Your name',
              _name.text.trim().isEmpty ? 'Not provided' : _name.text.trim(),
            ),
            _summary(
              'Contact',
              _contact.text.trim().isEmpty
                  ? 'Not provided'
                  : _contact.text.trim(),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      EvidenceSection(controller: _evidence, readOnly: true),
      if (_submissionMessage != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            _submissionMessage!,
            style: const TextStyle(color: RoadSafeColors.orange),
          ),
        ),
      const SizedBox(height: 20),
      _notice(
        Icons.fact_check_outlined,
        'What happens after submission?',
        'The RoadSafe team reviews and verifies reports on the website, then coordinates responder deployment when needed.',
      ),
      const SizedBox(height: 16),
      _notice(
        Icons.lock_outline,
        'Ready for review',
        'Sign in to send this report and track updates. Photos are uploaded privately with your report.',
      ),
    ],
  );

  Widget _footer() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
    decoration: const BoxDecoration(
      color: RoadSafeColors.background,
      border: Border(top: BorderSide(color: RoadSafeColors.border)),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (_step > 0) ...[
                  OutlinedButton(
                    onPressed: _sending || _submittedParams != null
                        ? null
                        : () => _goTo(_step - 1),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 52),
                    ),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sending || _loadingProfile
                        ? null
                        : _step < 2
                        ? _continue
                        : backend.ready
                        ? _sendReport
                        : null,
                    icon: Icon(
                      _step == 2 ? Icons.send_outlined : Icons.arrow_forward,
                      size: 18,
                    ),
                    label: Text(
                      [
                        'Continue',
                        'Review report',
                        _sending
                            ? 'Sending…'
                            : !backend.ready
                            ? 'Submission unavailable'
                            : _submission.reportId != null
                            ? 'Retry photo upload'
                            : backend.signedIn
                            ? 'Submit report'
                            : 'Sign in & submit',
                      ][_step],
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'For immediate danger, contact local emergency services.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: RoadSafeColors.muted),
            ),
          ],
        ),
      ),
    ),
  );

  static const _vehicleInfo = <String, (String, IconData)>{
    'car': ('Car', Icons.directions_car_outlined),
    'motorcycle': ('Motorcycle', Icons.two_wheeler),
    'tricycle': ('Tricycle', Icons.electric_rickshaw_outlined),
    'jeepney': ('Jeepney', Icons.directions_bus_filled_outlined),
    'van': ('Van', Icons.airport_shuttle_outlined),
    'bus': ('Bus', Icons.directions_bus_outlined),
    'truck': ('Truck', Icons.local_shipping_outlined),
    'bicycle': ('Bicycle', Icons.pedal_bike),
    'other': ('Other', Icons.more_horiz),
    'unknown': ('Unknown type', Icons.help_outline),
  };

  Widget _vehicleTile(String type) {
    final (label, icon) = _vehicleInfo[type]!;
    final count = _vehicles[type] ?? 0;
    final active = count > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      decoration: BoxDecoration(
        color: active
            ? RoadSafeColors.orange.withValues(alpha: 0.10)
            : RoadSafeColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? RoadSafeColors.orange : RoadSafeColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? RoadSafeColors.orange : RoadSafeColors.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Remove $type',
                visualDensity: VisualDensity.compact,
                onPressed: count == 0
                    ? null
                    : () => setState(() {
                        if (count == 1) {
                          _vehicles.remove(type);
                        } else {
                          _vehicles[type] = count - 1;
                        }
                      }),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: active ? RoadSafeColors.orange : null,
                ),
              ),
              IconButton(
                tooltip: 'Add $type',
                visualDensity: VisualDensity.compact,
                color: RoadSafeColors.orange,
                onPressed: count >= 999
                    ? null
                    : () => setState(() => _vehicles[type] = count + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
  );

  Widget _summary(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: RoadSafeColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(height: 1.5)),
      ],
    ),
  );

  Widget _notice(IconData icon, String title, String description) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: RoadSafeColors.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: RoadSafeColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: RoadSafeColors.orange, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  color: RoadSafeColors.muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
