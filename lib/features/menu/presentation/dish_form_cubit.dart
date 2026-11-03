import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/data_failure.dart';
import '../domain/dish.dart';
import '../domain/image_uploader.dart';
import '../domain/menu_repository.dart';
import '../domain/photo_picker.dart';
import 'dish_form_state.dart';

// Add or edit one dish (RES-3). Give [dish] to edit it.
class DishFormCubit extends Cubit<DishFormState> {
  DishFormCubit(
    this._repository, {
    required this._uploader,
    required this._picker,
    required this._restaurantId,
    Dish? dish,
  }) : super(
          dish == null
              ? const DishFormState()
              : DishFormState(
                  original: dish,
                  name: dish.name,
                  description: dish.description,
                  price: '${dish.price}',
                  category: dish.category,
                  available: dish.available,
                ),
        );

  final MenuRepository _repository;
  final ImageUploader _uploader;
  final PhotoPicker _picker;
  final String _restaurantId;

  void nameChanged(String value) => emit(state.copyWith(name: value));

  void descriptionChanged(String value) =>
      emit(state.copyWith(description: value));

  void priceChanged(String value) => emit(state.copyWith(price: value));

  void categoryChanged(String value) => emit(state.copyWith(category: value));

  void availableChanged(bool value) => emit(state.copyWith(available: value));

  // Shows a preview only. The upload happens on Save.
  Future<void> pickPhoto() async {
    if (state.isBusy) return;
    try {
      final path = await _picker.pickFromGallery();
      if (path == null || isClosed) return;
      emit(state.copyWith(photoPath: path));
    } catch (error) {
      _failed(error);
    }
  }

  // Clears the link only. Cloudinary files can't be deleted from the app.
  void removePhoto() {
    if (state.isBusy) return;
    emit(state.copyWith(imageUrl: '', clearPhotoPath: true));
  }

  Future<void> save() async {
    if (state.isBusy) return;
    if (!state.isValid) {
      emit(state.copyWith(showErrors: true));
      return;
    }

    // The new link stays in the state, so a failed save does not
    // upload again.
    String? url;
    if (state.needsUpload) {
      url = await _uploadPhoto();
      if (url == null) return;
    }

    emit(
      state.copyWith(
        imageUrl: url,
        clearPhotoPath: url != null,
        showErrors: true,
        status: DishFormStatus.saving,
      ),
    );
    final dish = state.toDish(_restaurantId);

    try {
      if (state.isEditing) {
        await _repository.updateDish(dish);
      } else {
        await _repository.addDish(dish);
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          status: DishFormStatus.saved,
          notice: state.isEditing
              ? '${dish.name} is saved.'
              : '${dish.name} is added to the menu.',
          noticeId: state.noticeId + 1,
        ),
      );
    } catch (error) {
      _failed(error);
    }
  }

  // The photo's link, or null when the upload fails.
  Future<String?> _uploadPhoto() async {
    final path = state.photoPath!;
    emit(
      state.copyWith(
        showErrors: true,
        status: DishFormStatus.uploading,
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
      return isClosed ? null : url;
    } catch (error) {
      _failed(error);
      return null;
    }
  }

  Future<void> delete() async {
    final dish = state.original;
    if (dish == null || state.isBusy) return;

    emit(state.copyWith(status: DishFormStatus.deleting));
    try {
      await _repository.deleteDish(dish);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: DishFormStatus.deleted,
          notice: '${dish.name} is deleted.',
          noticeId: state.noticeId + 1,
        ),
      );
    } catch (error) {
      _failed(error);
    }
  }

  // The page stays open, so the owner can try again.
  void _failed(Object error) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: DishFormStatus.editing,
        notice: error is DataFailure
            ? error.message
            : 'Something went wrong. Please try again.',
        noticeId: state.noticeId + 1,
      ),
    );
  }
}