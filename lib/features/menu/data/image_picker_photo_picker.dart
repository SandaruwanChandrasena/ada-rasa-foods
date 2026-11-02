import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/data_failure.dart';
import '../domain/photo_picker.dart';

// Uses the image_picker package. It makes the photo smaller first,
// so it uploads fast and saves Cloudinary space.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker(this._picker);

  final ImagePicker _picker;

  static const double maxSize = 1024;
  static const int quality = 80;

  @override
  Future<String?> pickFromGallery() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxSize,
        maxHeight: maxSize,
        imageQuality: quality,
      );
      return file?.path;
    } on PlatformException {
      throw const DataFailure('Could not open your photos.');
    }
  }
}