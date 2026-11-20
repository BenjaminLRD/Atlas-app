import 'dart:io';

import 'package:flutter/foundation.dart';

/// Keeps a picked profile photo in the app's own storage.
///
/// The gallery picker hands back a copy inside the app's cache folder, which
/// the system may clear. This copies it next to (not inside) the cache, in the
/// app's private area, and returns the new path. If anything goes wrong it
/// returns the original path, so picking a photo never fails because of this.
class ProfilePhotoStore {
  const ProfilePhotoStore._();

  static const String folderName = 'atlas_profile';

  /// Copies [pickedPath] into the app's private profile folder. [baseDir]
  /// overrides where that folder is created (used by tests).
  static Future<String> persist(String pickedPath, {Directory? baseDir}) async {
    if (kIsWeb) return pickedPath;
    try {
      final source = File(pickedPath);
      if (!await source.exists()) return pickedPath;
      final root = baseDir ?? source.parent.parent;
      final dir = Directory('${root.path}${Platform.pathSeparator}$folderName');
      if (!await dir.exists()) await dir.create(recursive: true);
      final ext = pickedPath.contains('.')
          ? pickedPath.substring(pickedPath.lastIndexOf('.'))
          : '.jpg';
      // A new name each time so the new picture is never served from the
      // image cache of the old one.
      final target = File(
        '${dir.path}${Platform.pathSeparator}avatar_'
        '${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await source.copy(target.path);
      // Remove the previous copies; only the newest is used.
      await for (final f in dir.list()) {
        if (f is File && f.path != target.path) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
      return target.path;
    } catch (_) {
      return pickedPath;
    }
  }
}
