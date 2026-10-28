import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import 'forgot_password_state.dart';

// Sends the password reset email (AUTH-3).
class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  ForgotPasswordCubit(this._repository) : super(const ForgotPasswordState());

  final AuthRepository _repository;

  Future<void> sendReset(String email) async {
    if (state.status == ForgotPasswordStatus.sending) return;

    emit(const ForgotPasswordState(status: ForgotPasswordStatus.sending));
    try {
      await _repository.sendPasswordReset(email);
      emit(const ForgotPasswordState(status: ForgotPasswordStatus.sent));
    } on AuthFailure catch (e) {
      emit(
        ForgotPasswordState(
          status: ForgotPasswordStatus.failure,
          errorMessage: e.message,
        ),
      );
    }
  }
}