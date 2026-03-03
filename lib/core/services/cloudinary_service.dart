import 'dart:io';
import 'package:dio/dio.dart';
import '../utils/env.dart';

/// Cloudinary service for image and video uploads
/// Full implementation in Phase 5
class CloudinaryService {
  CloudinaryService._();

  static final Dio _dio = Dio();

  /// Upload an image to Cloudinary
  /// Returns the secure URL of the uploaded image
  static Future<String?> uploadImage(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'upload_preset': Env.cloudinaryUploadPreset,
        'cloud_name': Env.cloudinaryCloudName,
        'folder': 'ripple/images',
      });

      final response = await _dio.post(
        'https://api.cloudinary.com/v1_1/${Env.cloudinaryCloudName}/image/upload',
        data: formData,
      );

      if (response.statusCode == 200) {
        return response.data['secure_url'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Upload a video to Cloudinary
  static Future<String?> uploadVideo(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'upload_preset': Env.cloudinaryUploadPreset,
        'cloud_name': Env.cloudinaryCloudName,
        'folder': 'ripple/videos',
        'resource_type': 'video',
      });

      final response = await _dio.post(
        'https://api.cloudinary.com/v1_1/${Env.cloudinaryCloudName}/video/upload',
        data: formData,
      );

      if (response.statusCode == 200) {
        return response.data['secure_url'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
