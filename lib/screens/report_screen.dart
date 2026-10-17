import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/roadsafe_theme.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../widgets/incident_location_picker.dart';
import '../widgets/evidence_section.dart';
import '../backend/backend.dart';
import '../backend/account_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, this.locationPickerBuilder});

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
  String _injuries = 'Not sure';
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _evidence.recoverLostPhotos();
    }
  }

  @override
  void dispose() {
    for (final controller in [_description, _name, _contact]) {
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
    final backend = RoadSafeBackend.instance;
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
      _submittedParams ??= buildSubmissionParams(
        submissionId: _submission.id,
        category: _category!,
        description: _description.text,
        latitude: _confirmedLocation!.latitude,
        longitude: _confirmedLocation!.longitude,
        occurredAt: _incidentAt ?? DateTime.now(),
        injuries: _injuries == 'No injuries'
            ? 'none'
            : _injuries == 'Someone is hurt'
            ? 'injured'
            : 'unknown',
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
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Report received'),
          content: Text(
            'Reference: ${_submission.reportId}\n\nYour report is saved and awaiting verification. Track its progress under Your reports.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
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

  void _continue() {
    if (_evidence.busy) return;
    final valid = _step == 0
        ? _detailsKey.currentState!.validate()
        : _locationKey.currentState!.validate();
    if (valid) _goTo(_step + 1);
  }

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
                              'Report an accident',
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
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.shield_outlined,
            size: 23,
            color: Colors.white,
          ),
        ),
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
        ['Accident details', 'Location & contact', 'Review'][_step],
        style: const TextStyle(fontSize: 12, color: RoadSafeColors.muted),
      ),
    ],
  );

  Widget _details() => Form(
    key: _detailsKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('What kind of accident?'),
        FormField<String>(
          validator: (_) =>
              _category == null ? 'Select an accident type' : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._categories.entries.map((entry) {
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
                                  entry.value.$1,
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
          children: ['Not sure', 'No injuries', 'Someone is hurt']
              .map(
                (label) => ChoiceChip(
                  label: Text(label),
                  selected: _injuries == label,
                  onSelected: (_) => setState(() => _injuries = label),
                  selectedColor: RoadSafeColors.orange.withValues(alpha: 0.16),
                  showCheckmark: true,
                ),
              )
              .toList(),
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
        const SizedBox(height: 28),
        _label('Your name (optional)'),
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(
            hintText: 'How should we address you?',
          ),
        ),
        const SizedBox(height: 20),
        _label('Contact number (optional)'),
        TextFormField(
          controller: _contact,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(
            hintText: 'A number the team can reach you on',
          ),
        ),
        const SizedBox(height: 20),
        _notice(
          Icons.info_outline,
          'Why share contact details?',
          'The team may need to clarify your report. You can leave these fields empty.',
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
            _summary('Accident type', _categories[_category]!.$1),
            _summary('Incident time', _incidentTimeLabel()),
            _summary('Injuries', _injuries),
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
                    onPressed: _sending
                        ? null
                        : _step < 2
                        ? _continue
                        : RoadSafeBackend.instance.ready
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
                            : !RoadSafeBackend.instance.ready
                            ? 'Submission unavailable'
                            : _submission.reportId != null
                            ? 'Retry photo upload'
                            : RoadSafeBackend.instance.signedIn
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
