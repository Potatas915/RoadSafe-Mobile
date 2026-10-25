import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend.dart';
import 'username.dart';
import '../theme/roadsafe_theme.dart';
import '../widgets/roadsafe_logo.dart';

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
    if (widget.enforcer && !_register) {
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
          () => _message = 'Could not load stations. Retry before signing in.',
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
  String? _message;
  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
      _messageOk = false;
    });
    try {
      if (_register) {
        final signedIn = await backend.signUp(
          _username.text,
          _password.text,
          accountType: _accountType,
        );
        if (!mounted) return;
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
                'Account created. Switch to Sign in and use your username and password.';
          });
          return;
        }
      } else {
        await backend.signIn(_username.text, _password.text);
      }
      if (widget.enforcer && !_register) {
        try {
          await backend.client.rpc('get_enforcer_context');
          await backend.client.rpc(
            'set_enforcer_duty',
            params: {'p_station': _station, 'p_on_duty': true},
          );
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

  String get _title => _register
      ? 'Create your account'
      : widget.enforcer
      ? 'Enforcer sign in'
      : 'Welcome back';

  String get _subtitle => _register
      ? 'Pick the account that fits you. Traffic enforcers need Admin verification before staff access is granted.'
      : widget.enforcer
      ? 'Choose your station. Signing in puts you on duty and makes you available on its map roster when you have no active case.'
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
              Icon(Icons.badge_outlined, size: 14, color: RoadSafeColors.orange),
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
        if (widget.enforcer && !_register) ...[
          DropdownButtonFormField<String>(
            initialValue: _station,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Station',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            items: _stations
                .map(
                  (s) => DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text(
                      '${s['name']} — ${s['address']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy || _loadingStations
                ? null
                : (value) => setState(() => _station = value),
            validator: (value) =>
                value == null ? 'Choose your stationed location' : null,
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
        TextFormField(
          controller: _username,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.username],
          decoration: InputDecoration(
            labelText: 'Username',
            prefixIcon: const Icon(Icons.person_outline),
            helperText: _register
                ? '3–24 letters, numbers or underscores. Start with a letter.'
                : null,
            helperMaxLines: 2,
          ),
          validator: (v) => v == null || v.trim().isEmpty
              ? 'Enter your username'
              : _register && !validUsername(v)
              ? 'Choose a valid username'
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
              v == null || v.length < 8 ? 'Use at least 8 characters' : null,
        ),
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
                    _register ? 'Create account' : 'Sign in',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ],
    ),
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
          onTap: _busy ? null : () => setState(() => _accountType = type),
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
      _register ? 'Already have an account? Sign in' : 'New here? Create an account',
    ),
  );
}
