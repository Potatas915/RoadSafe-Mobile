import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:roadsafe_mobile/widgets/incident_location_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'Fallback is not confirmed; moving a selected pin requires reconfirmation',
      () {
    final controller = IncidentLocationController();
    addTearDown(controller.dispose);
    controller.confirm();
    expect(controller.confirmed, isFalse);
    controller.select(const LatLng(14.85, 120.88));
    controller.confirm();
    expect(controller.confirmed, isTrue);
    controller.setMoving(true);
    controller.select(const LatLng(14.86, 120.89));
    controller.confirm();
    expect(controller.confirmed, isFalse);
    controller.setMoving(false);
    controller.confirm();
    expect(controller.confirmed, isTrue);
    expect(controller.target, const LatLng(14.86, 120.89));
  });

  test(
      'Restored confirmed pin stays selected and invalid coordinates are ignored',
      () {
    final controller = IncidentLocationController(
        initialLocation: const LatLng(14.85, 120.88));
    addTearDown(controller.dispose);
    expect(controller.confirmed, isTrue);
    controller.select(const LatLng(double.nan, 120));
    expect(controller.target, const LatLng(14.85, 120.88));
    expect(controller.confirmed, isTrue);
  });

  const channel = MethodChannel('flutter.baseflow.com/geolocator');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
      'Disabled GPS gives a manual selection message without requesting permission',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'isLocationServiceEnabled');
      return false;
    });
    await expectLater(
        findDeviceLocation(),
        throwsA(isA<LocationLookupException>().having(
            (e) => e.message, 'message', contains('move the map manually'))));
  });

  test(
      'Denied permission can be requested and denial keeps manual selection available',
      () async {
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return call.method == 'isLocationServiceEnabled' ? true : 0;
    });
    await expectLater(
        findDeviceLocation(), throwsA(isA<LocationLookupException>()));
    expect(methods,
        ['isLocationServiceEnabled', 'checkPermission', 'requestPermission']);
  });

  test('Blocked permission is not repeatedly requested', () async {
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return call.method == 'isLocationServiceEnabled' ? true : 1;
    });
    await expectLater(
        findDeviceLocation(),
        throwsA(isA<LocationLookupException>()
            .having((e) => e.message, 'message', contains('device settings'))));
    expect(methods, ['isLocationServiceEnabled', 'checkPermission']);
  });

  test('Granted permission returns current GPS coordinates', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isLocationServiceEnabled':
          return true;
        case 'checkPermission':
          return 2;
        case 'getCurrentPosition':
          return <String, dynamic>{
            'latitude': 14.85,
            'longitude': 120.88,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'accuracy': 10.0,
            'altitude': 0.0,
            'altitude_accuracy': 0.0,
            'heading': 0.0,
            'heading_accuracy': 0.0,
            'speed': 0.0,
            'speed_accuracy': 0.0,
          };
        default:
          throw StateError(call.method);
      }
    });
    expect(await findDeviceLocation(), const LatLng(14.85, 120.88));
  });
}
