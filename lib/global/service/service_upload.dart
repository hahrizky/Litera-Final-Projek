import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:litera2/global/service/service_base_upload.dart';
import 'package:litera2/global/service/service_cloudinary.dart';

/// Main entry point for image uploads.
/// Uses a fallback strategy to ensure reliability.
class ImageUploadService implements BaseImageUploadService {
  final List<BaseImageUploadService> _providers = [
    CloudinaryService(),
  ];

  @override
  Future<String> uploadImage(File file) async {
    Object? lastError;
    
    for (var provider in _providers) {
      try {
        return await provider.uploadImage(file);
      } catch (e) {
        debugPrint('[ImageUploadService] Provider ${provider.runtimeType} failed, trying next...');
        lastError = e;
        continue;
      }
    }
    
    throw Exception('All image upload providers failed. Last error: $lastError');
  }

  @override
  Future<void> deleteImage(String url) async {
    for (var provider in _providers) {
      try {
        await provider.deleteImage(url);
      } catch (_) {}
    }
  }
}