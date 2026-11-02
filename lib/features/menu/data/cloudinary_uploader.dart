import 'package:dio/dio.dart';

import '../../../core/errors/data_failure.dart';
import '../domain/image_uploader.dart';

// Uploads to Cloudinary with an unsigned preset. No secret is in the app.
class CloudinaryUploader implements ImageUploader {
  CloudinaryUploader(this._dio);

  final Dio _dio;

  // Not secrets. Anyone may know them.
  static const String cloudName = 'dtmcqgolr';
  static const String uploadPreset = 'ada_rasa_unsigned';

  static const String uploadUrl =
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  // Slow internet still gets time, but we never wait for ever.
  static const Duration timeout = Duration(seconds: 60);

  static const String failedMessage =
      'The photo could not be uploaded. Please try again.';

  @override
  Future<String> upload(
    String filePath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'upload_preset': uploadPreset,
      });

      final response = await _dio.post<Map<String, dynamic>>(
        uploadUrl,
        data: form,
        options: Options(sendTimeout: timeout, receiveTimeout: timeout),
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) onProgress(sent / total);
        },
      );

      final url = response.data?['secure_url'];
      if (url is! String || url.isEmpty) {
        throw const DataFailure(failedMessage);
      }
      return url;
    } on DataFailure {
      rethrow;
    } on DioException catch (error) {
      throw _toFailure(error);
    } catch (_) {
      throw const DataFailure(failedMessage);
    }
  }

  static DataFailure _toFailure(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const DataFailure(
          'No internet connection. Please try again.',
        );
      default:
        return const DataFailure(failedMessage);
    }
  }
}