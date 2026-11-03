import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/data_failure.dart';
import '../../menu/domain/image_uploader.dart';
import '../../menu/domain/photo_picker.dart';
import '../domain/restaurant_repository.dart';

enum RestaurantPhotoStatus { idle, uploading, saving }

// The owner's restaurant photo on the Menu tab (RES-3).
class RestaurantPhotoState extends Equatable {
  const RestaurantPhotoState({
    this.status = RestaurantPhotoStatus.idle,
    this.photoPath,
    this.uploadProgress = 0,
    this.notice,
    this.noticeId = 0,
  });

  final RestaurantPhotoStatus status;

  // The picked photo, shown while it uploads. Null when idle.
  final String? photoPath;

  // From 0 to 1 while the photo uploads.
  final double uploadProgress;

  // A message for the owner. A new noticeId means "show it now".
  final String? notice;
  final int noticeId;

  bool get isUploading => status == RestaurantPhotoStatus.uploading;

  bool get isBusy => status != RestaurantPhotoStatus.idle;

  // Use clearPhotoPath to forget the picked photo.
  RestaurantPhotoState copyWith({
    RestaurantPhotoStatus? status,
    String? photoPath,
    bool clearPhotoPath = false,
    double? uploadProgress,
    String? notice,
    int? noticeId,
  }) {
    return RestaurantPhotoState(
      status: status ?? this.status,
      photoPath: clearPhotoPath ? null : photoPath ?? this.photoPath,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      notice: notice ?? this.notice,
      noticeId: noticeId ?? this.noticeId,
    );
  }

  @override
  List<Object?> get props =>
      [status, photoPath, uploadProgress, notice, noticeId];
}

// Kept in one file with its state, so this part stays small.
// The live photo comes from MyRestaurantCubit; this cubit only changes it.
class RestaurantPhotoCubit extends Cubit<RestaurantPhotoState> {
  RestaurantPhotoCubit(
    this._repository, {
    required this._uploader,
    required this._picker,
    required this._restaurantId,
  }) : super(const RestaurantPhotoState());

  final RestaurantRepository _repository;
  final ImageUploader _uploader;
  final PhotoPicker _picker;
  final String _restaurantId;

  // True while the gallery or the "Use this photo?" sheet is open.
  bool _picking = false;

  static const String savedMessage = 'Restaurant photo is saved.';
  static const String removedMessage = 'Restaurant photo is removed.';

  // No Save button here, so the photo uploads right after the owner
  // taps Use photo in the [confirm] sheet.
  Future<void> pickAndUpload({required ConfirmPhoto confirm}) async {
    if (state.isBusy || _picking) return;

    String? path;
    _picking = true;
    try {
      path = await _pickConfirmed(confirm);
    } catch (error) {
      _failed(error);
      return;
    } finally {
      _picking = false;
    }
    if (path == null || isClosed) return;

    emit(
      state.copyWith(
        status: RestaurantPhotoStatus.uploading,
        photoPath: path,
        uploadProgress: 0,
      ),
    );

    try {
      final url = await _uploader.upload(
        path,
        onProgress: (progress) {
          if (isClosed || !state.isUploading) return;
          emit(
            state.copyWith(
              uploadProgress: progress.clamp(0.0, 1.0).toDouble(),
            ),
          );
        },
      );
      if (isClosed) return;

      emit(state.copyWith(status: RestaurantPhotoStatus.saving));
      await _repository.setImageUrl(_restaurantId, url);
      _done(savedMessage);
    } catch (error) {
      _failed(error);
    }
  }

  // Opens the gallery again after Pick another.
  // Null when the owner closes the gallery or taps Cancel.
  Future<String?> _pickConfirmed(ConfirmPhoto confirm) async {
    while (true) {
      final path = await _picker.pickFromGallery();
      if (path == null || isClosed) return null;

      final choice = await confirm(path);
      if (isClosed) return null;
      switch (choice) {
        case PhotoChoice.use:
          return path;
        case PhotoChoice.cancel:
          return null;
        case PhotoChoice.pickAnother:
          continue;
      }
    }
  }

  // Clears the link only. Cloudinary files can't be deleted from the app.
  // The page asks "Remove the restaurant photo?" before calling this.
  Future<void> removePhoto() async {
    if (state.isBusy || _picking) return;

    emit(state.copyWith(status: RestaurantPhotoStatus.saving));
    try {
      await _repository.setImageUrl(_restaurantId, '');
      _done(removedMessage);
    } catch (error) {
      _failed(error);
    }
  }

  void _done(String message) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: RestaurantPhotoStatus.idle,
        clearPhotoPath: true,
        uploadProgress: 0,
        notice: message,
        noticeId: state.noticeId + 1,
      ),
    );
  }

  // The old photo stays, because nothing was saved.
  void _failed(Object error) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: RestaurantPhotoStatus.idle,
        clearPhotoPath: true,
        uploadProgress: 0,
        notice: error is DataFailure
            ? error.message
            : 'Something went wrong. Please try again.',
        noticeId: state.noticeId + 1,
      ),
    );
  }
}