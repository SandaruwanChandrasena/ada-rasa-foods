// Sends a photo to the internet and gives back its link.
// Throws DataFailure.
abstract class ImageUploader {
  // [onProgress] gets a number from 0 to 1 while it uploads.
  Future<String> upload(
    String filePath, {
    void Function(double progress)? onProgress,
  });
}