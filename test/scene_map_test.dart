import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:roadsafe_mobile/screens/scene_map.dart';

class ScenePlatform extends Fake implements MapLibrePlatform {
  @override
  void dispose() {}
  @override
  Widget buildView(
    Map<String, dynamic> params,
    dynamic created,
    dynamic gestures,
  ) => const SizedBox.expand();
}

class SceneController extends Fake implements MapLibreMapController {
  final cameras = <CameraUpdate>[];
  @override
  Future<bool?> animateCamera(CameraUpdate update, {Duration? duration}) async {
    cameras.add(update);
    return true;
  }
}

void main() {
  testWidgets(
    'map enables gestures and zoom controls without changing saved accident target',
    (tester) async {
      final factory = MapLibrePlatform.createInstance;
      MapLibrePlatform.createInstance = () => ScenePlatform();
      addTearDown(() => MapLibrePlatform.createInstance = factory);
      await tester.pumpWidget(
        const MaterialApp(
          home: SceneMap(
            latitude: 14.8433,
            longitude: 120.8114,
            facility: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final map = tester.widget<MapLibreMap>(find.byType(MapLibreMap));
      expect(map.scrollGesturesEnabled, isTrue);
      expect(map.zoomGesturesEnabled, isTrue);
      expect(
        map.initialCameraPosition!.target,
        const LatLng(14.8433, 120.8114),
      );
      final controller = SceneController();
      map.onMapCreated!(controller);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.tap(find.byTooltip('Center accident'));
      expect(controller.cameras.length, 3);
      expect(
        controller.cameras.last.toJson(),
        CameraUpdate.newLatLngZoom(
          const LatLng(14.8433, 120.8114),
          15.5,
        ).toJson(),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
