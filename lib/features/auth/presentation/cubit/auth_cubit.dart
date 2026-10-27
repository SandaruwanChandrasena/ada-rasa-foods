import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthState.unknown());

  final AuthRepository _repository;

  // Runs once when the app starts.
  Future<void> checkSession() async {
    try {
      final user = await _repository.getCurrentUser();
      emit(
        user == null
            ? const AuthState.unauthenticated()
            : AuthState.authenticated(user),
      );
    } on AuthFailure catch (e) {
      emit(AuthState.unauthenticated(errorMessage: e.message));
    }
  }

  Future<void> signInWithGoogle() {
    return _signIn(_repository.signInWithGoogle);
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _signIn(
      () => _repository.signInWithEmail(
        email: email.trim(),
        password: password,
      ),
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _signIn(
      () => _repository.registerWithEmail(
        name: name.trim(),
        email: email.trim(),
        password: password,
      ),
    );
  }

  Future<void> signOut() async {
    try {
      await _repository.signOut();
    } on AuthFailure {
      // Show the login screen even if sign-out failed.
    }
    emit(const AuthState.unauthenticated());
  }

  // Shared by Google, email sign-in, and sign-up.
  Future<void> _signIn(Future<AppUser?> Function() action) async {
    if (state.isLoading) return; // Stops double taps.

    emit(const AuthState.unauthenticated(isLoading: true));
    try {
      final user = await action();
      emit(
        user == null
            ? const AuthState.unauthenticated() // Google picker was closed.
            : AuthState.authenticated(user),
      );
    } on AuthFailure catch (e) {
      emit(AuthState.unauthenticated(errorMessage: e.message));
    }
  }
}