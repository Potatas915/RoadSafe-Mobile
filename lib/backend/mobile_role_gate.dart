import 'dart:async';
import 'package:flutter/material.dart';
import 'backend.dart';
import '../screens/home_screen.dart';
import '../screens/enforcer_screen.dart';

class MobileRoleGate extends StatefulWidget {
  const MobileRoleGate({super.key});
  @override
  State<MobileRoleGate> createState() => _MobileRoleGateState();
}

class _MobileRoleGateState extends State<MobileRoleGate> {
  final backend = RoadSafeBackend.instance;
  Timer? timer;
  String? role;
  String? error;
  String? owner;
  int generation = 0;
  bool checking = false;
  @override
  void initState() {
    super.initState();
    backend.addListener(refresh);
    if (backend.ready) {
      timer = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
    }
    refresh();
  }

  Future<void> refresh() async {
    final current = ++generation;
    final uid = backend.userId;
    if (uid == null) {
      if (mounted) {
        setState(() {
          role = null;
          owner = null;
          error = null;
          checking = false;
        });
      }
      return;
    }
    if (owner != uid) {
      role = null;
      checking = true;
      owner = uid;
    }
    try {
      final row = await backend.client
          .from('user_roles')
          .select('role,enabled')
          .eq('user_id', uid)
          .single();
      if (!mounted || current != generation) return;
      setState(() {
        checking = false;
        role = row['role'] as String?;
        error = row['enabled'] != true
            ? 'This account is suspended. Contact an administrator.'
            : null;
      });
    } catch (_) {
      if (mounted && current == generation) {
        setState(() {
          checking = false;
          role = null;
          error = 'Could not confirm account access. Retry or sign out.';
        });
      }
    }
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    backend.removeListener(refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null ||
        role == 'Admin' ||
        (backend.signedIn && !['Public', 'Officer'].contains(role))) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(error ?? 'Use the web dashboard for administrator work.'),
                TextButton(onPressed: refresh, child: const Text('Retry')),
                TextButton(
                  onPressed: backend.signOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (role == 'Officer') {
      return EnforcerScreen(key: ValueKey(owner));
    }
    return const HomeScreen();
  }
}
