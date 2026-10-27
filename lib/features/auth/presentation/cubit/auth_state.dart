import 'package:equatable/equatable.dart';

import '../../domain/entities/app_user.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState extends Equatable {
  const AuthState._({
    required this.status,
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  // App just started. Still checking for a saved login.
  const AuthState.unknown() : this._(status: AuthStatus.unknown);

  const AuthState.unauthenticated({
    bool isLoading = false,
    String? errorMessage,
  }) : this._(
          status: AuthStatus.unauthenticated,
          isLoading: isLoading,
          errorMessage: errorMessage,
        );

  const AuthState.authenticated(AppUser user)
      : this._(status: AuthStatus.authenticated, user: user);

  final AuthStatus status;
  final AppUser? user;
  final bool isLoading;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, user, isLoading, errorMessage];
}