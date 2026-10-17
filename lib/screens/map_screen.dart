import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../theme/roadsafe_theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GIS Tactical Map'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(children: [
        MapLibreMap(
          onMapCreated: (controller) => _controller = controller,
          initialCameraPosition: const CameraPosition(
            target: LatLng(14.85, 120.88),
            zoom: 11,
          ),
          styleString:
              'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json',
        ),
        Positioned(
          right: 16,
          bottom: 96,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            tooltip: 'Recenter on Bulacan',
            backgroundColor: RoadSafeColors.card,
            foregroundColor: RoadSafeColors.orange,
            onPressed: () => _controller?.animateCamera(
              CameraUpdate.newLatLngZoom(const LatLng(14.85, 120.88), 11),
            ),
            child: const Icon(Icons.my_location),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 32,
          child: IgnorePointer(
              child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RoadSafeColors.card,
              border: Border.all(color: RoadSafeColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 17, color: RoadSafeColors.orange),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Map preview · Incident layers are not connected.',
                      style: TextStyle(
                          color: RoadSafeColors.muted, fontSize: 11))),
            ]),
          )),
        ),
      ]),
    );
  }
}
