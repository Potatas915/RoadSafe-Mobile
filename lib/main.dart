import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'backend/mobile_role_gate.dart';
import 'theme/roadsafe_theme.dart';
import 'backend/backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TextureView supports the clipped, scrolling map and its Flutter overlays.
  MapLibreMap.useHybridComposition = true;
  await RoadSafeBackend.instance.initialize();
  runApp(const RoadSafeApp());
}

class RoadSafeApp extends StatelessWidget {
  const RoadSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoadTrack',
      debugShowCheckedModeBanner: false,
      theme: buildRoadSafeTheme(),
      home: const MobileRoleGate(),
    );
  }
}
