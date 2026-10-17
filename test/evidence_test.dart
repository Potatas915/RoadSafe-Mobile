import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roadsafe_mobile/widgets/evidence_section.dart';

class TestImagePicker extends ImagePicker {
  XFile? camera;
  List<XFile> gallery = [];
  PlatformException? error;
  ImageSource? source;
  LostDataResponse recovered = LostDataResponse.empty();

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    if (error != null) throw error!;
    return camera;
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    source = ImageSource.gallery;
    if (error != null) throw error!;
    return gallery;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async => recovered;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List png;
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const Color(0xFFFF7700), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(2, 2);
    png = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    image.dispose();
    picture.dispose();
  });
  XFile photo(String name) =>
      XFile.fromData(png, path: name, name: name, mimeType: 'image/png');

  test(
    'Camera and gallery attach images; cancelling does not change evidence',
    () async {
      final picker = TestImagePicker()..camera = photo('camera.png');
      final evidence = EvidenceController(picker: picker);
      addTearDown(evidence.dispose);
      await evidence.pick(ImageSource.camera);
      expect(picker.source, ImageSource.camera);
      expect(evidence.photos.length, 1);
      picker.camera = null;
      await evidence.pick(ImageSource.camera);
      expect(evidence.photos.length, 1);
      expect(evidence.message, isNull);
      picker.gallery = [photo('gallery.png')];
      await evidence.pick(ImageSource.gallery);
      expect(picker.source, ImageSource.gallery);
      expect(evidence.photos.length, 2);
    },
  );

  test('Limit is enforced and removing evidence makes room', () async {
    final picker = TestImagePicker()
      ..gallery = List.generate(6, (i) => photo('$i.png'));
    final evidence = EvidenceController(picker: picker);
    addTearDown(evidence.dispose);
    await evidence.pick(ImageSource.gallery);
    expect(evidence.photos.length, 5);
    expect(evidence.message, contains('up to 5'));
    evidence.remove(evidence.photos.first);
    picker.gallery = [photo('replacement.png')];
    await evidence.pick(ImageSource.gallery);
    expect(evidence.photos.last.file.name, 'replacement.png');
    expect(evidence.photos.length, 5);
  });

  test(
    'Access denial and unreadable or oversized files give recoverable errors',
    () async {
      final picker = TestImagePicker()
        ..error = PlatformException(code: 'camera_access_denied');
      final evidence = EvidenceController(picker: picker);
      addTearDown(evidence.dispose);
      await evidence.pick(ImageSource.camera);
      expect(evidence.message, contains('denied'));
      expect(evidence.busy, isFalse);
      picker.error = null;
      picker.gallery = [XFile.fromData(Uint8List(10), name: 'invalid.png')];
      await evidence.pick(ImageSource.gallery);
      expect(evidence.photos, isEmpty);
      expect(evidence.message, contains('could not be opened'));
      picker.gallery = [
        XFile.fromData(
          Uint8List(EvidenceController.maxBytes + 1),
          name: 'large.png',
        ),
      ];
      await evidence.pick(ImageSource.gallery);
      expect(evidence.photos, isEmpty);
      expect(evidence.message, contains('too large'));
    },
  );

  test('Interrupted Android picker files are recovered', () async {
    final picker = TestImagePicker()
      ..recovered = LostDataResponse(files: [photo('recovered.png')]);
    final evidence = EvidenceController(picker: picker);
    addTearDown(evidence.dispose);
    await evidence.recoverLostPhotos();
    expect(evidence.photos.single.file.name, 'recovered.png');
    expect(evidence.busy, isFalse);
  });

  testWidgets(
    'Evidence thumbnails can be previewed and removed; review is read only',
    (tester) async {
      final picker = TestImagePicker()..gallery = [photo('preview.png')];
      final evidence = EvidenceController(picker: picker);
      addTearDown(evidence.dispose);
      await tester.runAsync(() => evidence.pick(ImageSource.gallery));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EvidenceSection(controller: evidence)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove photo 1'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Preview evidence photo 1'));
      await tester.pumpAndSettle();
      expect(find.text('Close photo'), findsOneWidget);
      await tester.tap(find.text('Close photo'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceSection(controller: evidence, readOnly: true),
          ),
        ),
      );
      expect(find.byTooltip('Remove photo 1'), findsNothing);
      expect(find.text('Camera'), findsNothing);
      expect(
        find.text('1 photo(s) attached · Not uploaded yet'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EvidenceSection(controller: evidence)),
        ),
      );
      await tester.tap(find.byTooltip('Remove photo 1'));
      await tester.pump();
      expect(find.text('No photos attached.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
