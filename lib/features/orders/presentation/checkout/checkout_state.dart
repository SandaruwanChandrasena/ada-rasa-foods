import 'package:equatable/equatable.dart';

enum CheckoutStatus { ready, placing, placed, failure }

class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.ready,
    this.orderId,
    this.errorMessage,
  });

  final CheckoutStatus status;

  // Set when the order is saved. The status screen opens with it.
  final String? orderId;

  final String? errorMessage;

  bool get isPlacing => status == CheckoutStatus.placing;

  @override
  List<Object?> get props => [status, orderId, errorMessage];
}