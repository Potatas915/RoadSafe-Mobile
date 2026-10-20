import 'package:flutter/material.dart';
import 'backend/mobile_role_gate.dart';
import 'theme/roadsafe_theme.dart';
import 'backend/backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RoadSafeBackend.instance.initialize();
  runApp(const RoadSafeApp());
}

class RoadSafeApp extends StatelessWidget {
  const RoadSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoadSafe Mobile',
      debugShowCheckedModeBanner: false,
      theme: buildRoadSafeTheme(),
      home: const MobileRoleGate(),
    );
  }
}
