import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import '../multimodal/chat_attachment.dart';

/// How a photo request ended.
enum ImagePickOutcome {
  /// A photo was taken or chosen.
  picked,

  /// The user closed the camera or gallery without choosing.
  cancelled,

  /// The camera or gallery could not be used (permission, no camera, the file
  /// could not be read).
  failed,
}

/// The result of asking for a photo, with a message the user can read.
class ImagePickResult {
  final ImagePickOutcome outcome;
  final ChatAttachment? attachment;
  final String? message;

  const ImagePickResult._(this.outcome, this.attachment, this.message);

  const ImagePickResult.picked(ChatAttachment attachment)
    : this._(ImagePickOutcome.picked, attachment, null);

  const ImagePickResult.cancelled()
    : this._(ImagePickOutcome.cancelled, null, 'No photo was selected.');

  const ImagePickResult.failed(String message)
    : this._(ImagePickOutcome.failed, null, message);
}

/// Picks and prepares fitness photos (camera or gallery) as chat attachments.
class AIVisionService {
  final ImagePicker _picker;

  AIVisionService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// Picks an image from the specified [source] (Camera or Gallery) with compression
  Future<ChatAttachment?> pickImage({
    required ImageSource source,
    double maxWidth = 1280,
    double maxHeight = 1280,
    int imageQuality = 85,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      if (pickedFile == null) return null;
      return await ChatAttachment.fromXFile(pickedFile);
    } catch (_) {
      return null;
    }
  }

  /// Like [pickImage], but says *why* there is no photo: cancelled, or failed
  /// (permission denied, no camera, unreadable file). [pickImage] returns null
  /// for all of these.
  Future<ImagePickResult> pickWithOutcome({
    required ImageSource source,
    double maxWidth = 1280,
    double maxHeight = 1280,
    int imageQuality = 85,
  }) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
    } on PlatformException catch (e) {
      final camera = source == ImageSource.camera;
      if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied') {
        return ImagePickResult.failed(
          camera
              ? 'Camera access is off. Allow it in Settings, or choose a photo from your gallery.'
              : 'Photo access is off. Allow it in Settings, or take a photo instead.',
        );
      }
      return ImagePickResult.failed(
        camera
            ? 'The camera could not be opened. Try again, or choose a photo from your gallery.'
            : 'The gallery could not be opened. Try again, or take a photo instead.',
      );
    } catch (_) {
      return const ImagePickResult.failed(
        'The photo could not be loaded. Try again.',
      );
    }

    if (file == null) return const ImagePickResult.cancelled();

    final attachment = await ChatAttachment.fromXFile(file);
    if (attachment == null) {
      return const ImagePickResult.failed(
        'The photo could not be read. Try another one.',
      );
    }
    return ImagePickResult.picked(attachment);
  }

  /// Convenience helper to pick an image from the device photo gallery
  Future<ChatAttachment?> pickFromGallery({int imageQuality = 85}) {
    return pickImage(source: ImageSource.gallery, imageQuality: imageQuality);
  }

  /// Convenience helper to capture an image directly from the camera
  Future<ChatAttachment?> pickFromCamera({int imageQuality = 85}) {
    return pickImage(source: ImageSource.camera, imageQuality: imageQuality);
  }

  /// Validates and compresses raw bytes into a [ChatAttachment]
  ChatAttachment? prepareImageBytes({
    required Uint8List bytes,
    String mimeType = 'image/jpeg',
    String? fileName,
  }) {
    if (bytes.isEmpty) return null;
    if (bytes.length > 4 * 1024 * 1024) {
      // 4MB limit check
      return null;
    }

    final base64String = base64Encode(bytes);
    return ChatAttachment(
      base64Data: base64String,
      mimeType: mimeType,
      fileName: fileName ?? 'image.jpg',
      byteSize: bytes.length,
    );
  }
}
