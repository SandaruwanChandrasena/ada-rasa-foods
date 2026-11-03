// Lets the owner pick a photo from the phone gallery.
// Throws DataFailure.
abstract class PhotoPicker {
  // The picked file's path, or null if the owner cancels.
  Future<String?> pickFromGallery();
}

// What the owner chose in the "Use this photo?" sheet.
enum PhotoChoice { use, pickAnother, cancel }

// Shows the picked photo and waits for the owner's choice.
typedef ConfirmPhoto = Future<PhotoChoice> Function(String path);