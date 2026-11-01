import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/domain/app_user.dart';
import '../../auth/domain/auth_failure.dart';
import '../../auth/domain/auth_repository.dart';
import 'edit_profile_state.dart';

// Saves a new name and phone (CUS-6). The screen then tells AuthCubit.
class EditProfileCubit extends Cubit<EditProfileState> {
  EditProfileCubit(this._repository) : super(const EditProfileState());

  final AuthRepository _repository;

  Future<void> save({
    required AppUser user,
    required String name,
    required String phone,
  }) async {
    // A second tap must never save twice.
    if (state.isSaving || state.status == EditProfileStatus.saved) return;

    emit(const EditProfileState(status: EditProfileStatus.saving));
    try {
      final updated = await _repository.updateProfile(
        user: user,
        name: name,
        phone: phone,
      );
      if (isClosed) return;
      emit(EditProfileState(status: EditProfileStatus.saved, user: updated));
    } on AuthFailure catch (e) {
      if (isClosed) return;
      emit(
        EditProfileState(
          status: EditProfileStatus.failure,
          errorMessage: e.message,
        ),
      );
    }
  }
}