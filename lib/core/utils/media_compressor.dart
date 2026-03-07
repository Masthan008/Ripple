import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Utility class for compressing images and videos before upload
class MediaCompressor {
  MediaCompressor._();

  /// Compress an image file. Returns the compressed file.
  /// Falls back to the original file if compression fails.
  static Future<File> compressImage(String filePath) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        filePath,
        targetPath,
        quality: 75,
        minWidth: 1080,
        minHeight: 1080,
        keepExif: false,
      );

      if (result != null) {
        return File(result.path);
      }
      return File(filePath);
    } catch (_) {
      return File(filePath);
    }
  }

  /// Get human-readable file size string
  static String getFileSizeString(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get file extension from path
  static String getExtension(String path) {
    final parts = path.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }
}
