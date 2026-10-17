import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend.dart';
import 'username.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _form = GlobalKey<FormState>();

  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
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
      final backend = RoadSafeBackend.instance;
      if (_register) {
        final signedIn = await backend.signUp(_username.text, _password.text);
        if (!mounted) return;
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
      title: Text(_register ? 'Create your account' : 'Sign in to RoadSafe'),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your account keeps your reports and updates together. Your report draft stays here while you sign in.',
            ),
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
                onPressed: _busy || !RoadSafeBackend.instance.ready
                    ? null
                    : _submit,
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
                  : () => setState(() {
                      _register = !_register;
                      _message = null;
                    }),
              child: Text(
                _register
                    ? 'Already have an account? Sign in'
                    : 'New here? Create an account',
              ),
            ),
            if (_message != null) Text(_message!),
            if (!RoadSafeBackend.instance.ready)
              const Text(
                'The backend is unavailable. Restart the app and retry.',
              ),
          ],
        ),
      ),
    ),
  );
}
