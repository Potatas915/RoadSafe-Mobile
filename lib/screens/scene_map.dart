import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../backend/scene_route.dart';
import '../theme/roadsafe_theme.dart';

class SceneMap extends StatefulWidget {
  const SceneMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.station,
    this.title = 'Accident location',
    this.facility = false,
  });
  final double latitude, longitude;
  final Map? station;
  final String title;
  final bool facility;
  @override
  State<SceneMap> createState() => _SceneMapState();
}

class _SceneMapState extends State<SceneMap> {
  MapLibreMapController? _map;
  String? _routeMessage;
  LatLng get _destination => LatLng(widget.latitude, widget.longitude);

  Future<void> _loadMap() async {
    final map = _map;
    if (map == null) return;
    try {
      // Register a native marker whose tip is anchored to the saved coordinates.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final path = Path()
        ..moveTo(24, 60)
        ..cubicTo(20, 50, 2, 31, 2, 23)
        ..arcToPoint(const Offset(46, 23), radius: const Radius.circular(22))
        ..cubicTo(46, 31, 28, 50, 24, 60)
        ..close();
      canvas.drawPath(path, Paint()..color = RoadSafeColors.orange);
      canvas.drawCircle(const Offset(24, 23), 8, Paint()..color = Colors.white);
      final picture = recorder.endRecording();
      final image = await picture.toImage(48, 64);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      if (!mounted) return;
      await map.addImage('scene-pin', bytes!.buffer.asUint8List());
      await map.setSymbolIconAllowOverlap(true);
      await map.addSymbol(
        SymbolOptions(
          geometry: _destination,
          iconImage: 'scene-pin',
          iconAnchor: 'bottom',
          iconSize: 0.8,
        ),
      );
      if (widget.facility) return;
      final station = stationLocation(widget.station);
      if (station == null) {
        if (mounted) {
          setState(
            () => _routeMessage =
                'Station location unavailable. Accident pin is shown.',
          );
        }
        return;
      }
      await map.addCircle(
        CircleOptions(
          geometry: station,
          circleRadius: 9,
          circleColor: '#2563eb',
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 3,
        ),
      );
      final points = await loadSceneRoute(station, _destination);
      if (!mounted) return;
      await map.addLine(
        LineOptions(
          geometry: points,
          lineColor: '#2563eb',
          lineWidth: 5,
          lineOpacity: 0.85,
        ),
      );
      final all = [station, _destination, ...points];
      await map.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              all.map((p) => p.latitude).reduce(math.min),
              all.map((p) => p.longitude).reduce(math.min),
            ),
            northeast: LatLng(
              all.map((p) => p.latitude).reduce(math.max),
              all.map((p) => p.longitude).reduce(math.max),
            ),
          ),
          left: 48,
          top: 48,
          right: 48,
          bottom: 48,
        ),
      );
      if (mounted) {
        setState(
          () => _routeMessage =
              'Blue route: ${widget.station?['name'] ?? 'your station'} to accident.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _routeMessage =
              'Could not load the map route. The accident location remains selected. Reopen to retry.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${widget.facility ? 'Mapped facility' : 'Accident pin'}: ${widget.latitude}, ${widget.longitude}\n${_routeMessage ?? (widget.facility ? 'Location information only. Capacity and acceptance are unconfirmed.' : 'Loading station route…')}',
            style: const TextStyle(fontSize: 12.5, height: 1.5),
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MapLibreMap(
                initialCameraPosition: CameraPosition(
                  target: _destination,
                  zoom: 15.5,
                ),
                styleString:
                    'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json',
                onMapCreated: (controller) => _map = controller,
                onStyleLoadedCallback: _loadMap,
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
              ),
              Positioned(
                right: 12,
                bottom: 24,
                child: Material(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Zoom in',
                        icon: const Icon(Icons.add),
                        onPressed: () =>
                            _map?.animateCamera(CameraUpdate.zoomIn()),
                      ),
                      IconButton(
                        tooltip: 'Zoom out',
                        icon: const Icon(Icons.remove),
                        onPressed: () =>
                            _map?.animateCamera(CameraUpdate.zoomOut()),
                      ),
                      IconButton(
                        tooltip: 'Center accident',
                        icon: const Icon(Icons.location_on),
                        onPressed: () => _map?.animateCamera(
                          CameraUpdate.newLatLngZoom(_destination, 15.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
