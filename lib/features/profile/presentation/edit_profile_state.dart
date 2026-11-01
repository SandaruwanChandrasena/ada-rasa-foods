import 'package:equatable/equatable.dart';

import '../../auth/domain/app_user.dart';

enum EditProfileStatus { editing, saving, saved, failure }

class EditProfileState extends Equatable {
  const EditProfileState({
    this.status = EditProfileStatus.editing,
    this.user,
    this.errorMessage,
  });

  final EditProfileStatus status;

  // The updated user, after a good save.
  final AppUser? user;

  final String? errorMessage;

  bool get isSaving => status == EditProfileStatus.saving;

  @override
  List<Object?> get props => [status, user, errorMessage];
}