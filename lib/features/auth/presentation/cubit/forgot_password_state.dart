import 'package:equatable/equatable.dart';

enum ForgotPasswordStatus { initial, sending, sent, failure }

class ForgotPasswordState extends Equatable {
  const ForgotPasswordState({
    this.status = ForgotPasswordStatus.initial,
    this.errorMessage,
  });

  final ForgotPasswordStatus status;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, errorMessage];
}