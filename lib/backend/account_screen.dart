import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend.dart';
import 'username.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    this.enforcer = false,
    this.registration = false,
    this.backend,
  });
  final bool enforcer;
  final bool registration;
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
            setState(
              () => _message =
                  'Account created. An Admin must verify your enforcer application before you can sign in as an enforcer.',
            );
          }
          return;
        }
        if (!signedIn) {
          setState(
            () => _message =
                'Account created. Switch to Sign in and use your username and password.',
          );
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _register
            ? 'Create your account'
            : widget.enforcer
            ? 'Enforcer sign in'
            : 'Sign in to RoadSafe',
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _register
                  ? 'Choose your account type. Traffic enforcers need Admin verification before staff access is granted.'
                  : widget.enforcer
                  ? 'Choose your station. Signing in puts you on duty and makes you available on its map roster when you have no active case.'
                  : 'Your account keeps your reports and updates together. Your report draft stays here while you sign in.',
            ),
            if (_register)
              DropdownButtonFormField<String>(
                initialValue: _accountType,
                decoration: const InputDecoration(labelText: 'Account type'),
                items: const [
                  DropdownMenuItem(value: 'Public', child: Text('User')),
                  DropdownMenuItem(
                    value: 'Officer',
                    child: Text('Traffic enforcer'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _accountType = value!),
              ),
            if (widget.enforcer && !_register) ...[
              DropdownButtonFormField<String>(
                initialValue: _station,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Station'),
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
              if (_loadingStations) const LinearProgressIndicator(),
              if (!_loadingStations && _stations.isEmpty)
                const Text(
                  'No cached stations available. Ask an Admin to share the police-station directory from the map.',
                ),
              TextButton(
                onPressed: _busy || _loadingStations ? null : _loadStations,
                child: const Text('Refresh stations'),
              ),
            ],
            const SizedBox(height: 24),
            TextFormField(
              controller: _username,
              keyboardType: TextInputType.text,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.username],
              decoration: InputDecoration(
                labelText: 'Username',
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
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) => v == null || v.length < 8
                  ? 'Use at least 8 characters'
                  : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy || !backend.ready ? null : _submit,
                child: Text(
                  _busy
                      ? 'Please wait…'
                      : _register
                      ? 'Create account'
                      : 'Sign in',
                ),
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
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
            ),
            if (_message != null) Text(_message!),
            if (!backend.ready)
              const Text(
                'The backend is unavailable. Restart the app and retry.',
              ),
          ],
        ),
      ),
    ),
  );
}
