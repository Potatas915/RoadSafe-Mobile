import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend.dart';
import 'username.dart';
import 'reporter_validation.dart';
import '../theme/roadsafe_theme.dart';
import '../widgets/roadsafe_logo.dart';
import '../widgets/station_search.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    this.enforcer = false,
    this.registration = false,
    this.direct = false,
    this.backend,
  });
  final bool enforcer;
  final bool registration;

  /// True when opened straight from the landing page. Sign in and create
  /// account then swap places instead of stacking on top of each other.
  final bool direct;
  final RoadSafeBackend? backend;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final backend = widget.backend ?? RoadSafeBackend.instance;
  final _form = GlobalKey<FormState>();

  final _username = TextEditingController();
  final _email = TextEditingController();
  final _mobileNumber = TextEditingController();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  String get _fullName => [_firstName.text, _middleName.text, _lastName.text]
      .map((part) => part.trim().replaceAll(RegExp(r'\s+'), ' '))
      .where((part) => part.isNotEmpty)
      .join(' ');
  final _password = TextEditingController();
  bool get _register => widget.registration;
  String _accountType = 'Public';
  List<Map<String, dynamic>> _stations = [];
  String? _station;
  bool _loadingStations = false;
  @override
  void initState() {
    super.initState();
    _accountType = widget.enforcer ? 'Officer' : 'Public';
    if (widget.enforcer && _register) {
      _loadStations();
    }
  }

  Future<void> _loadStations() async {
    setState(() {
      _loadingStations = true;
      _message = null;
    });
    try {
      final rows = await backend.client.rpc('get_login_stations');
      if (mounted) {
        setState(() {
          _stations = (rows as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
          if (!_stations.any((s) => s['id'] == _station)) {
            _station = null;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _message = 'Could not load stations. Refresh stations to retry.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingStations = false);
      }
    }
  }

  bool _busy = false;
  bool _showPassword = false;
  bool _messageOk = false;
  bool _accountCreated = false;
  String? _message;
  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _mobileNumber.dispose();
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_accountCreated) {
      _openSignIn();
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (_register) {
      final nameError = validateReporterName(_fullName);
      if (nameError != null) {
        setState(() {
          _messageOk = false;
          _message = nameError;
        });
        return;
      }
    }
    setState(() {
      _busy = true;
      _message = null;
      _messageOk = false;
    });
    try {
      if (_register) {
        final signedIn = await backend.signUp(
          _email.text,
          _password.text,
          fullName: _fullName,
          mobileNumber: _mobileNumber.text,
          username: _accountType == 'Officer' ? null : _username.text,
          accountType: _accountType,
          stationId: _accountType == 'Officer' ? _station : null,
        );
        if (!mounted) return;
        setState(() => _accountCreated = true);
        if (_accountType == 'Officer') {
          if (signedIn) await backend.signOut();
          if (mounted) {
            setState(() {
              _messageOk = true;
              _message =
                  'Account created. An Admin must verify your enforcer application before you can sign in as an enforcer.';
            });
          }
          return;
        }
        if (!signedIn) {
          setState(() {
            _messageOk = true;
            _message =
                _accountType == 'Officer' ? 'Account created. Sign in with your email and password.' : 'Account created. Sign in with your email or username and password.';
          });
          return;
        }
      } else {
        if (widget.enforcer) {
          await backend.signIn(_username.text, _password.text);
        } else {
          await backend.signInResident(_username.text, _password.text);
        }
      }
      if (widget.enforcer && !_register) {
        try {
          final context = await backend.client.rpc('get_enforcer_context');
          final savedStation = (context as Map)['stationId'] as String?;
          if (savedStation != null) {
            await backend.client.rpc(
              'set_enforcer_duty_checked',
              params: {
                'p_station': savedStation,
                'p_on_duty': true,
                'p_expected_station_id': savedStation,
              },
            );
          }
        } catch (_) {
          await backend.signOut();
          throw const AuthException(
            'Admin-approved police Officer access and a valid station are required. If you have an active case, keep your assigned station.',
          );
        }
      }
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not connect. Check your internet connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _errorColor = Color(0xFFF87171);

  void _openSignIn() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => AccountScreen(
          enforcer: _accountType == 'Officer',
          direct: widget.direct,
          backend: backend,
        ),
      ),
    );
  }

  String get _title => _register
      ? 'Create your account'
      : widget.enforcer
      ? 'Enforcer sign in'
      : 'Welcome back';

  String get _subtitle => _register
      ? 'Pick the account that fits you. Traffic enforcers need Admin verification before staff access is granted.'
      : widget.enforcer
      ? 'Sign in with your saved station. You appear on its roster when on duty and free of active cases. If you have no saved station yet, choose one after signing in.'
      : 'Your account keeps your reports and updates together. Your report draft stays here while you sign in.';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _form,
              autovalidateMode: _register
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 24),
                  _card(),
                  const SizedBox(height: 12),
                  Center(child: _switchLink()),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const RoadSafeLogo(size: 56),
      const SizedBox(height: 20),
      if (widget.enforcer && !_register) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: RoadSafeColors.orange.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.badge_outlined,
                size: 14,
                color: RoadSafeColors.orange,
              ),
              SizedBox(width: 6),
              Text(
                'TRAFFIC ENFORCER',
                style: TextStyle(
                  color: RoadSafeColors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      Text(
        _title,
        style: const TextStyle(
          fontSize: 28,
          height: 1.15,
          letterSpacing: -0.8,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        _subtitle,
        style: const TextStyle(
          color: RoadSafeColors.muted,
          fontSize: 14,
          height: 1.55,
        ),
      ),
    ],
  );

  Widget _card() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: RoadSafeColors.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: RoadSafeColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_register) ...[
          const Text(
            'I am a',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _typeTile(
                'Public',
                Icons.person_outline,
                'Resident',
                'Report accidents',
              ),
              const SizedBox(width: 10),
              _typeTile(
                'Officer',
                Icons.badge_outlined,
                'Traffic enforcer',
                'Needs Admin approval',
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (_register && _accountType == 'Officer') ...[
          FormField<String>(
            initialValue: _station,
            key: ValueKey(_station),
            validator: (value) =>
                value == null ? 'Choose your stationed location' : null,
            builder: (field) {
              final selected = _stations
                  .where((s) => s['id'] == _station)
                  .firstOrNull;
              return InkWell(
                key: const Key('registration-station-picker'),
                onTap: _busy || _loadingStations || _stations.isEmpty
                    ? null
                    : () async {
                        final selected = await showSearch<String?>(
                          context: context,
                          delegate: StationSearch(_stations),
                        );
                        if (!mounted || selected == null) return;
                        field.didChange(selected);
                        setState(() => _station = selected);
                      },
                child: InputDecorator(
                  isEmpty: selected == null,
                  decoration: InputDecoration(
                    labelText: 'Station',
                    prefixIcon: const Icon(Icons.place_outlined),
                    suffixIcon: const Icon(Icons.search),
                    errorText: field.errorText,
                    helperText: 'Search Philippine stations by name or address',
                    helperMaxLines: 2,
                    enabled:
                        !_busy && !_loadingStations && _stations.isNotEmpty,
                  ),
                  child: Text(
                    selected == null
                        ? ''
                        : '${selected['name']} — ${selected['address']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          ),
          if (_loadingStations)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(),
            ),
          if (!_loadingStations && _stations.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'No cached stations available. Ask an Admin to share the police-station directory from the map.',
                style: TextStyle(
                  color: RoadSafeColors.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy || _loadingStations ? null : _loadStations,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh stations'),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_register) ...[
          if (_accountType != 'Officer') ...[
          TextFormField(
            controller: _username,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(
              labelText: 'Username',
              helperText: 'Sign in with this username or your contact email.',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            validator: (value) => validUsername(value ?? '')
                ? null
                : 'Use 3–24 letters, numbers or underscores; start with a letter.',
          ),
          const SizedBox(height: 16),
          ],
          _nameField(_firstName, 'First name', AutofillHints.givenName),
          const SizedBox(height: 16),
          _nameField(
            _middleName,
            'Middle name',
            AutofillHints.middleName,
            optional: true,
          ),
          const SizedBox(height: 16),
          _nameField(_lastName, 'Last name', AutofillHints.familyName),
          const SizedBox(height: 16),
        ],
        TextFormField(
          controller: _register ? _email : _username,
          keyboardType: _register || widget.enforcer
              ? TextInputType.emailAddress
              : TextInputType.text,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: _register || widget.enforcer
              ? const [AutofillHints.email]
              : const [AutofillHints.username],
          decoration: InputDecoration(
            labelText: _register || widget.enforcer ? 'Email' : 'Email or username',
            prefixIcon: const Icon(Icons.alternate_email),
            helperText: _register
                ? (_accountType == 'Officer' ? 'Use this email to sign in.' : 'Sign in with this email or your username.')
                : null,
            helperMaxLines: 2,
          ),
          validator: (v) => v == null || v.trim().isEmpty
              ? (_register || widget.enforcer
                    ? 'Enter your email'
                    : 'Enter your email or username')
              : (_register || widget.enforcer) && !validAccountEmail(v)
              ? 'Enter a valid email address'
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _password,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) {
            if (!_busy && backend.ready) _submit();
          },
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            helperText: _register ? 'Use at least 8 characters.' : null,
            suffixIcon: IconButton(
              tooltip: _showPassword ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          validator: (v) =>
              v == null || v.isEmpty
              ? 'Enter your password'
              : _register && v.trim().isEmpty
              ? 'Password cannot contain only spaces'
              : v.length < 8
              ? 'Use at least 8 characters'
              : null,
        ),
        if (_register) ...[
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('registration-mobile'),
            controller: _mobileNumber,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            maxLength: 20,
            validator: validateReporterContact,
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              hintText: 'e.g. 0917 123 4567',
              helperText: 'Saved to your profile for accident reports.',
              prefixIcon: Icon(Icons.phone_outlined),
              counterText: '',
            ),
          ),
        ],
        if (_message != null) ...[
          const SizedBox(height: 16),
          _banner(
            _messageOk ? Icons.check_circle_outline : Icons.error_outline,
            _message!,
            _messageOk ? RoadSafeColors.green : _errorColor,
          ),
        ],
        if (!backend.ready) ...[
          const SizedBox(height: 16),
          _banner(
            Icons.cloud_off_outlined,
            'The backend is unavailable. Restart the app and retry.',
            _errorColor,
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy || !backend.ready ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _register && !_accountCreated
                        ? 'Create account'
                        : 'Sign in',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ],
    ),
  );

  Widget _nameField(
    TextEditingController controller,
    String label,
    String autofillHint, {
    bool optional = false,
  }) => TextFormField(
    controller: controller,
    textCapitalization: TextCapitalization.words,
    textInputAction: TextInputAction.next,
    autofillHints: [autofillHint],
    decoration: InputDecoration(
      labelText: label,
      helperText: optional ? 'Optional' : null,
      prefixIcon: const Icon(Icons.person_outline),
    ),
    validator: (value) {
      final part = (value ?? '').trim();
      if (part.isEmpty)
        return optional ? null : 'Enter your ${label.toLowerCase()}';
      if (part.length > 60) return 'Use at most 60 characters';
      if (!RegExp(
        r"^[\p{L}\p{M}][\p{L}\p{M} .'’-]*$",
        unicode: true,
      ).hasMatch(part)) {
        return 'Use letters only (no numbers or symbols)';
      }
      return null;
    },
  );

  Widget _typeTile(String type, IconData icon, String label, String caption) {
    final selected = _accountType == type;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          key: Key('account-type-$type'),
          borderRadius: BorderRadius.circular(16),
          onTap: _busy
              ? null
              : () {
                  setState(() => _accountType = type);
                  if (type == 'Officer' &&
                      _stations.isEmpty &&
                      !_loadingStations) {
                    _loadStations();
                  }
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? RoadSafeColors.orange.withValues(alpha: 0.12)
                  : RoadSafeColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? RoadSafeColors.orange : RoadSafeColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected
                      ? RoadSafeColors.orange
                      : RoadSafeColors.muted,
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: const TextStyle(
                    color: RoadSafeColors.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _banner(IconData icon, String text, Color color) => Container(
    width: double.infinity,
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
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5, height: 1.5),
          ),
        ),
      ],
    ),
  );

  Widget _switchLink() => TextButton(
    onPressed: _busy
        ? null
        : () async {
            if (widget.direct) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute<bool>(
                  builder: (_) => AccountScreen(
                    registration: !_register,
                    enforcer: widget.enforcer,
                    direct: true,
                    backend: backend,
                  ),
                ),
              );
              return;
            }
            if (_register) {
              Navigator.pop(context);
              return;
            }
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => AccountScreen(
                  registration: true,
                  enforcer: widget.enforcer,
                  backend: backend,
                ),
              ),
            );
            if (created == true && context.mounted) {
              Navigator.pop(context, true);
            }
          },
    child: Text(
      _register
          ? 'Already have an account? Sign in'
          : 'New here? Create an account',
    ),
  );
}
