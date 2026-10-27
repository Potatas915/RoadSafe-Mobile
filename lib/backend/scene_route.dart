import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

LatLng? stationLocation(Map? station) {
  final lat = station?['lat'], lng = station?['lng'];
  if (lat is! num ||
      lng is! num ||
      !lat.isFinite ||
      !lng.isFinite ||
      lat.abs() > 90 ||
      lng.abs() > 180) {
    return null;
  }
  return LatLng(lat.toDouble(), lng.toDouble());
}

Future<List<LatLng>> loadSceneRoute(
  LatLng from,
  LatLng to, {
  http.Client? client,
}) async {
  final ownClient = client == null;
  final transport = client ?? http.Client();
  try {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=geojson',
    );
    final response = await transport
        .get(uri)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw const FormatException('Route unavailable');
    }
    final body = jsonDecode(response.body);
    final routes = body['routes'] as List?;
    if (body['code'] != 'Ok' || routes == null || routes.isEmpty) {
      throw const FormatException('Route unavailable');
    }
    final geometry = routes.first['geometry'];
    final coordinates = geometry['coordinates'] as List?;
    if (geometry['type'] != 'LineString' ||
        coordinates == null ||
        coordinates.length < 2) {
      throw const FormatException('Invalid route');
    }
    return coordinates.map((point) {
      if (point is! List || point.length != 2) {
        throw const FormatException('Invalid route point');
      }
      final location = stationLocation({'lng': point[0], 'lat': point[1]});
      if (location == null) throw const FormatException('Invalid route point');
      return location;
    }).toList();
  } finally {
    if (ownClient) transport.close();
  }
}
