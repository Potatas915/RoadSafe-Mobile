import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:roadsafe_mobile/backend/scene_route.dart';

void main() {
  test(
    'station route sends longitude first and preserves accident endpoints',
    () async {
      final client = MockClient((request) async {
        final ends = request.url.path
            .split('/')
            .last
            .split(';')
            .map((end) => end.split(',').map(double.parse).toList())
            .toList();
        expect(ends[0][0], closeTo(120.8, 0.000001));
        expect(ends[0][1], closeTo(14.8, 0.000001));
        expect(ends[1][0], closeTo(120.8114, 0.000001));
        expect(ends[1][1], closeTo(14.8433, 0.000001));
        return http.Response(
          '{"code":"Ok","routes":[{"geometry":{"type":"LineString","coordinates":[[120.8,14.8],[120.81,14.84],[120.8114,14.8433]]}}]}',
          200,
        );
      });
      addTearDown(client.close);
      final points = await loadSceneRoute(
        const LatLng(14.8, 120.8),
        const LatLng(14.8433, 120.8114),
        client: client,
      );
      expect(points.first, const LatLng(14.8, 120.8));
      expect(points.last, const LatLng(14.8433, 120.8114));
    },
  );
  test(
    'invalid route fails rather than showing a fictional road route',
    () async {
      final client = MockClient(
        (_) async => http.Response('{"code":"NoRoute","routes":[]}', 200),
      );
      addTearDown(client.close);
      await expectLater(
        loadSceneRoute(
          const LatLng(14.8, 120.8),
          const LatLng(14.84, 120.81),
          client: client,
        ),
        throwsFormatException,
      );
      expect(stationLocation({'lat': 999, 'lng': 120}), isNull);
      expect(stationLocation(null), isNull);
      expect(
        stationLocation({'lat': 14.8, 'lng': 120.8}),
        const LatLng(14.8, 120.8),
      );
    },
  );
}
