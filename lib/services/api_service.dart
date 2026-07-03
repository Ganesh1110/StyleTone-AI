import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'profile_service.dart';

class ApiService {
  // CHANGE THIS TO YOUR DEPLOYED PYTHON BACKEND URL
  static const String baseUrl =
      'https://style-tone-ai.vercel.app'; // Production Vercel backend
  // static const String baseUrl = 'http://10.0.2.2:8000'; // Local backend for Android Emulator

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  Future<Map<String, dynamic>> getRecommendations({
    required File imageFile,
    required String occasion, // "office", "party", or "casual"
  }) async {
    try {
      // 1. Resize image to 400x400 to reduce payload
      final resizedFile = await _resizeImage(imageFile, 400);

      // 2. Convert to Base64
      List<int> imageBytes = await resizedFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // 3. Load User Profile to get gender
      final profile = await ProfileService().getProfile();

      // 4. Build Payload
      final payload = {
        'image': 'data:image/jpeg;base64,$base64Image',
        'occasion': occasion,
        'gender': profile.gender,
      };

      // 5. Send POST request
      final response = await _dio.post('/recommend', data: payload);

      if (response.statusCode == 200 && response.data is Map) {
        return response.data;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse && e.response?.data != null) {
        final detail = e.response!.data is Map
            ? (e.response!.data['detail'] ?? 'Server error (${e.response!.statusCode})')
            : 'Server error (${e.response!.statusCode})';
        throw Exception(detail);
      }
      throw Exception('Network error. Please check your connection and try again.');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Map<String, dynamic>> analyzeClothingColor({
    required File imageFile,
  }) async {
    try {
      // 1. Resize image to 400x400 to reduce payload size
      final resizedFile = await _resizeImage(imageFile, 400);

      // 2. Convert to Base64
      List<int> imageBytes = await resizedFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // 3. Build Payload
      final payload = {
        'image': 'data:image/jpeg;base64,$base64Image',
      };

      // 4. Send POST request
      final response = await _dio.post('/analyze-clothing', data: payload);

      if (response.statusCode == 200 && response.data is Map) {
        return response.data;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse && e.response?.data != null) {
        final detail = e.response!.data is Map
            ? (e.response!.data['detail'] ?? 'Server error (${e.response!.statusCode})')
            : 'Server error (${e.response!.statusCode})';
        throw Exception(detail);
      }
      throw Exception('Network error. Please check your connection and try again.');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  // Helper to resize image using the 'image' package
  Future<File> _resizeImage(File file, int maxSize) async {
    try {
      // Read the original image bytes
      final bytes = await file.readAsBytes();

      // Spawn a background isolate to perform the CPU-heavy image decode and resize
      final resizedBytes = await compute(_resizeImageIsolate, {
        'bytes': bytes,
        'maxSize': maxSize,
      });

      if (resizedBytes == null) return file;

      // Save the resulting bytes to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, 'resized_temp.jpg'));
      await tempFile.writeAsBytes(resizedBytes);

      return tempFile;
    } catch (e) {
      debugPrint('Isolate image resizing failed, returning original: $e');
      return file;
    }
  }

  // Static helper to compress and save a file to a persistent destination path
  static Future<File> compressAndSaveImage(File file, String targetPath, int maxSize) async {
    try {
      final bytes = await file.readAsBytes();
      final resizedBytes = await compute(_resizeImageIsolate, {
        'bytes': bytes,
        'maxSize': maxSize,
      });

      final targetFile = File(targetPath);
      if (resizedBytes != null) {
        await targetFile.writeAsBytes(resizedBytes);
      } else {
        await file.copy(targetPath);
      }
      return targetFile;
    } catch (e) {
      debugPrint('Isolate compression failed, copying original: $e');
      return await file.copy(targetPath);
    }
  }
}

// Top-level function for background isolate image resizing
List<int>? _resizeImageIsolate(Map<String, dynamic> params) {
  try {
    final Uint8List bytes = params['bytes'] as Uint8List;
    final int maxSize = params['maxSize'] as int;

    final image = img.decodeImage(bytes);
    if (image == null) return null;

    int width = image.width;
    int height = image.height;

    if (width > maxSize || height > maxSize) {
      if (width > height) {
        height = (height * maxSize / width).round();
        width = maxSize;
      } else {
        width = (width * maxSize / height).round();
        height = maxSize;
      }
    }

    final resizedImage = img.copyResize(image, width: width, height: height);
    return img.encodeJpg(resizedImage, quality: 85);
  } catch (e) {
    return null;
  }
}
