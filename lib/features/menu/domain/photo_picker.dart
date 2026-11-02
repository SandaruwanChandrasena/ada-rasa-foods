// Lets the owner pick a photo from the phone gallery.
// Throws DataFailure.
abstract class PhotoPicker {
  // The picked file's path, or null if the owner cancels.
  Future<String?> pickFromGallery();
}