import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../theme/roadsafe_theme.dart';

/// One-shot foreground location; no background tracking is requested.
Future<LatLng> findDeviceLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationLookupException(
      'Location services are off. Enable them and retry, or move the map manually.',
    );
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationLookupException(
      'Location permission is blocked. Enable it in device settings, or choose a spot manually.',
    );
  }
  if (permission != LocationPermission.always &&
      permission != LocationPermission.whileInUse) {
    throw const LocationLookupException(
      'Location permission was not granted. You can still move the map to the accident.',
    );
  }
  final position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
    timeLimit: const Duration(seconds: 15),
  );
  return LatLng(position.latitude, position.longitude);
}

class LocationLookupException implements Exception {
  const LocationLookupException(this.message);
  final String message;
}

/// Separate selection from confirmation so a moved pin cannot remain confirmed.
class IncidentLocationController extends ChangeNotifier {
  IncidentLocationController({LatLng? initialLocation})
    : target = initialLocation ?? const LatLng(14.85, 120.88),
      hasSelection = initialLocation != null,
      confirmed = initialLocation != null;

  LatLng target;
  bool hasSelection;
  bool confirmed;
  bool moving = false;

  void select(LatLng point) {
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180) {
      return;
    }

    target = point;
    hasSelection = true;
    confirmed = false;
    notifyListeners();
  }

  void setMoving(bool value) {
    moving = value;
    if (value) confirmed = false;
    notifyListeners();
  }

  void confirm() {
    if (!hasSelection || moving) return;
    confirmed = true;
    notifyListeners();
  }
}

class IncidentLocationPicker extends StatefulWidget {
  const IncidentLocationPicker({
    super.key,
    this.initialLocation,
    required this.onChanged,
  });

  final LatLng? initialLocation;

  /// Null means the pin has moved and requires explicit confirmation again.
  final ValueChanged<LatLng?> onChanged;

  @override
  State<IncidentLocationPicker> createState() => _IncidentLocationPickerState();
}

class _IncidentLocationPickerState extends State<IncidentLocationPicker> {
  static const double _streetZoom = 15.5;
  static const double _areaZoom = 11;
  late final IncidentLocationController _selection;
  MapLibreMapController? _map;
  bool _locating = false;
  bool _ready = false;
  String? _message;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _selection = IncidentLocationController(
      initialLocation: widget.initialLocation,
    );
    if (widget.initialLocation == null) _locate();
  }

  @override
  void dispose() {
    _request++;
    _selection.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    final request = ++_request;
    setState(() {
      _locating = true;
      _message = null;
    });
    try {
      final point = await findDeviceLocation();
      if (!mounted || request != _request) return;
      _selection.select(point);
      widget.onChanged(null);
      // A map is recreated only after leaving this step; onMapCreated handles
      // GPS results that arrive before the native map is ready.
      await _map?.moveCamera(CameraUpdate.newLatLngZoom(point, _streetZoom));
      if (!mounted || request != _request) return;
      setState(
        () => _message =
            'Current location found. Adjust the pin if needed, then confirm.',
      );
    } on LocationLookupException catch (error) {
      if (mounted && request == _request) {
        setState(() => _message = error.message);
      }
    } on TimeoutException {
      if (mounted && request == _request) {
        setState(
          () => _message =
              'Finding your location took too long. Retry or select the accident on the map.',
        );
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _message =
              'Could not get your location. Retry or choose a spot on the map.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _locating = false);
    }
  }

  void _zoom(double delta) {
    final camera = _map?.cameraPosition;
    if (camera == null) return;
    _map?.animateCamera(
      CameraUpdate.newLatLngZoom(
        camera.target,
        (camera.zoom + delta).clamp(1.0, 20.0),
      ),
    );
  }

  void _cameraMoved(CameraPosition position) {
    // Do not treat the fallback camera's initial position as a chosen incident.
    if (!_ready) return;
    if (_selection.target == position.target) return;
    _request++; // A late GPS result must not overwrite a manually chosen spot.
    _locating = false;
    _selection.setMoving(true);
    _selection.select(position.target);
    widget.onChanged(null);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _selection,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Move the map to place the pin at the accident. You can also tap a spot.',
          style: TextStyle(
            color: RoadSafeColors.muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 280,
            child: Stack(
              children: [
                MapLibreMap(
                  initialCameraPosition: CameraPosition(
                    target: _selection.target,
                    zoom: _selection.hasSelection ? _streetZoom : _areaZoom,
                  ),
                  styleString:
                      'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json',
                  trackCameraPosition: true,
                  zoomGesturesEnabled: true,
                  doubleClickZoomEnabled: true,
                  scrollGesturesEnabled: true,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                  onMapCreated: (controller) {
                    _map = controller;
                  },
                  onStyleLoadedCallback: () async {
                    await _map?.moveCamera(
                      CameraUpdate.newLatLngZoom(
                        _selection.target,
                        _selection.hasSelection ? _streetZoom : _areaZoom,
                      ),
                    );
                    if (mounted) setState(() => _ready = true);
                  },
                  onCameraMove: _cameraMoved,
                  onCameraIdle: () {
                    if (_ready) _selection.setMoving(false);
                  },
                  onMapClick: (_, point) async {
                    _request++;
                    setState(() => _locating = false);
                    _selection.select(point);
                    widget.onChanged(null);
                    await _map?.moveCamera(CameraUpdate.newLatLng(point));
                  },
                ),
                Center(
                  child: IgnorePointer(
                    child: Transform.translate(
                      offset: const Offset(0, -22),
                      child: const Icon(
                        Icons.location_pin,
                        color: RoadSafeColors.orange,
                        size: 44,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    elevation: 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Zoom in',
                          onPressed: _ready ? () => _zoom(1) : null,
                          icon: const Icon(Icons.add, color: Color(0xFF334155)),
                        ),
                        IconButton(
                          tooltip: 'Zoom out',
                          onPressed: _ready ? () => _zoom(-1) : null,
                          icon: const Icon(
                            Icons.remove,
                            color: Color(0xFF334155),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Use current location',
                          onPressed: _locating ? null : _locate,
                          icon: _locating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.my_location,
                                  color: Color(0xFF334155),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!_ready)
                  const Positioned(
                    top: 12,
                    left: 12,
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Loading map…',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_locating)
          const Text(
            'Finding your current location…',
            style: TextStyle(color: RoadSafeColors.muted, fontSize: 12),
          ),
        if (!_locating && _message != null)
          Text(
            _message!,
            style: const TextStyle(
              color: RoadSafeColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        if (_selection.hasSelection)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '${_selection.target.latitude.toStringAsFixed(6)}, ${_selection.target.longitude.toStringAsFixed(6)}',
              style: const TextStyle(color: RoadSafeColors.muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed:
                _ready &&
                    _selection.hasSelection &&
                    !_selection.moving &&
                    !_locating &&
                    !_selection.confirmed
                ? () {
                    _selection.confirm();
                    widget.onChanged(_selection.target);
                  }
                : null,
            icon: Icon(
              _selection.confirmed
                  ? Icons.check_circle_outline
                  : Icons.location_on_outlined,
              size: 18,
            ),
            label: Text(
              _selection.confirmed
                  ? 'Location confirmed'
                  : 'Confirm accident location',
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Map tiles require an internet connection.',
          style: TextStyle(color: RoadSafeColors.muted, fontSize: 11),
        ),
      ],
    ),
  );
}
