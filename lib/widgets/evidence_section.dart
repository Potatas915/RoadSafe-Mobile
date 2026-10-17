import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/roadsafe_theme.dart';

class EvidencePhoto {
  const EvidencePhoto({required this.file, required this.bytes});
  final XFile file;
  final Uint8List bytes;
}

/// Local attachments only; an upload service will consume these files later.
class EvidenceController extends ChangeNotifier {
  EvidenceController({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  static const maxPhotos = 5;
  static const maxBytes = 10 * 1024 * 1024;
  final ImagePicker _picker;
  final List<EvidencePhoto> _photos = [];
  List<EvidencePhoto> get photos => List.unmodifiable(_photos);
  bool busy = false;
  bool _disposed = false;
  String? message;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void remove(EvidencePhoto photo) {
    _photos.remove(photo);
    message = null;
    notifyListeners();
  }

  Future<void> _add(List<XFile> files) async {
    for (final file in files) {
      if (_disposed) return;
      if (_photos.any((photo) => photo.file.path == file.path)) continue;
      if (_photos.length >= maxPhotos) {
        message =
            'You can attach up to $maxPhotos photos. Remove one to add another.';
        break;
      }
      try {
        if (await file.length() > maxBytes) {
          message = 'A photo was too large. Choose images smaller than 10 MB.';
          continue;
        }
        final bytes = await file.readAsBytes();
        // Reject unreadable images before they become report evidence.
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256);
        final frame = await codec.getNextFrame();
        frame.image.dispose();
        codec.dispose();
        if (_disposed) return;
        _photos.add(EvidencePhoto(file: file, bytes: bytes));
      } catch (_) {
        message = 'A photo could not be opened. Try a different image.';
      }
    }
  }

  Future<void> pick(ImageSource source) async {
    if (busy || _photos.length >= maxPhotos) return;
    busy = true;
    message = null;
    notifyListeners();
    try {
      if (source == ImageSource.camera) {
        final file = await _picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
          requestFullMetadata: false,
        );
        if (file != null) await _add([file]);
      } else {
        final files = await _picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
          requestFullMetadata: false,
        );
        await _add(files);
      }
    } on PlatformException catch (error) {
      message =
          error.code.toLowerCase().contains('denied') ||
              error.code.toLowerCase().contains('access')
          ? 'Photo access was denied. Allow camera or photo access in device settings and try again.'
          : 'Could not open the camera or photo library. Please try again.';
    } catch (_) {
      message =
          'This device could not open the camera or photo library. Try choosing a photo instead.';
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  /// Android can restart the activity while the external camera is open.
  Future<void> recoverLostPhotos() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      final response = await _picker.retrieveLostData().timeout(
        const Duration(seconds: 5),
      );
      if (response.files != null) await _add(response.files!);
      if (response.exception != null) {
        message =
            'The previous photo could not be recovered. Please add it again.';
      }
    } catch (_) {
      message =
          'The previous photo could not be recovered. You can add photos again.';
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }
}

class EvidenceSection extends StatelessWidget {
  const EvidenceSection({
    super.key,
    required this.controller,
    this.readOnly = false,
  });
  final EvidenceController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          readOnly ? 'Evidence photos' : 'Evidence photos (optional)',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 8),
        if (!readOnly) ...[
          const Text(
            'Add photos only if it is safe. Up to 5 photos, 10 MB each.',
            style: TextStyle(
              color: RoadSafeColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed:
                    controller.busy ||
                        controller.photos.length >= EvidenceController.maxPhotos
                    ? null
                    : () => controller.pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Camera'),
              ),
              OutlinedButton.icon(
                onPressed:
                    controller.busy ||
                        controller.photos.length >= EvidenceController.maxPhotos
                    ? null
                    : () => controller.pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Choose photos'),
              ),
            ],
          ),
          if (controller.busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (controller.message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                controller.message!,
                style: const TextStyle(
                  color: RoadSafeColors.orange,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
        ],
        if (controller.photos.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No photos attached.',
              style: TextStyle(color: RoadSafeColors.muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: controller.photos.asMap().entries.map((entry) {
            final photo = entry.value;
            final number = entry.key + 1;
            return SizedBox(
              width: 108,
              height: 108,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Material(
                        child: InkWell(
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (context) => Dialog(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: InteractiveViewer(
                                      child: Image.memory(
                                        photo.bytes,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const Text('Photo unavailable'),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close photo'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          child: Semantics(
                            button: true,
                            label: 'Preview evidence photo $number',
                            child: Image.memory(
                              photo.bytes,
                              fit: BoxFit.cover,
                              cacheWidth: 240,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!readOnly)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        tooltip: 'Remove photo $number',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => controller.remove(photo),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
        if (controller.photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '${controller.photos.length} photo(s) attached · Not uploaded yet',
              style: const TextStyle(color: RoadSafeColors.muted, fontSize: 12),
            ),
          ),
      ],
    ),
  );
}
