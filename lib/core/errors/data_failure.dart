import 'package:equatable/equatable.dart';

// One error type for data features (restaurants, menu, and later orders).
class DataFailure extends Equatable implements Exception {
  const DataFailure(this.message);

  // A simple message we can show to the user.
  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => 'DataFailure: $message';
}