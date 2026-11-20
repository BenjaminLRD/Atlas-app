import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Represents an image attachment for multimodal AI Coach conversations.
class ChatAttachment {
  final String? filePath;
  final String? base64Data;
  final String mimeType;
  final String? fileName;
  final int byteSize;

  const ChatAttachment({
    this.filePath,
    this.base64Data,
    this.mimeType = 'image/jpeg',
    this.fileName,
    this.byteSize = 0,
  });

  /// Factory creating [ChatAttachment] from picked [XFile] with compression.
  static Future<ChatAttachment?> fromXFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final extension = file.name.split('.').last.toLowerCase();

      String mime = 'image/jpeg';
      if (extension == 'png') {
        mime = 'image/png';
      } else if (extension == 'webp') {
        mime = 'image/webp';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        mime = 'image/jpeg';
      } else {
        // Unsupported format fallback
        mime = 'image/jpeg';
      }

      final base64String = base64Encode(bytes);

      return ChatAttachment(
        filePath: file.path,
        base64Data: base64String,
        mimeType: mime,
        fileName: file.name,
        byteSize: bytes.length,
      );
    } catch (_) {
      return null;
    }
  }

  /// Factory creating [ChatAttachment] from raw bytes.
  factory ChatAttachment.fromBytes({
    required Uint8List bytes,
    required String mimeType,
    String? fileName,
  }) {
    return ChatAttachment(
      base64Data: base64Encode(bytes),
      mimeType: mimeType,
      fileName: fileName,
      byteSize: bytes.length,
    );
  }

  /// Decoded bytes if base64 data is present.
  Uint8List? get bytes {
    if (base64Data == null || base64Data!.isEmpty) return null;
    try {
      return base64Decode(base64Data!);
    } catch (_) {
      return null;
    }
  }

  /// True if attachment is a supported image format (JPEG, PNG, WebP).
  bool get isSupportedImage =>
      mimeType == 'image/jpeg' ||
      mimeType == 'image/png' ||
      mimeType == 'image/webp' ||
      mimeType == 'image/jpg';

  /// True if image payload is within reasonable API bounds (< 4 MB).
  bool get isWithinSizeLimit => byteSize <= 4 * 1024 * 1024;

  Map<String, dynamic> toJson() => {
    if (filePath != null) 'filePath': filePath,
    if (base64Data != null) 'base64Data': base64Data,
    'mimeType': mimeType,
    if (fileName != null) 'fileName': fileName,
    'byteSize': byteSize,
  };

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      filePath: json['filePath'] as String?,
      base64Data: json['base64Data'] as String?,
      mimeType: json['mimeType'] as String? ?? 'image/jpeg',
      fileName: json['fileName'] as String?,
      byteSize: (json['byteSize'] as num?)?.toInt() ?? 0,
    );
  }
}
