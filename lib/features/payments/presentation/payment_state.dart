import 'package:equatable/equatable.dart';

import '../domain/payment_card.dart';

// Steps of a demo card payment. No real money moves (CUS-10).
enum DemoPaymentStatus { idle, processing, approved, declined }

class PaymentState extends Equatable {
  const PaymentState({
    this.status = DemoPaymentStatus.idle,
    this.card,
    this.amount = 0,
  });

  final DemoPaymentStatus status;

  // The card being paid with. Null before the first payment.
  final PaymentCard? card;

  // Whole rupees.
  final int amount;

  bool get isProcessing => status == DemoPaymentStatus.processing;

  @override
  List<Object?> get props => [status, card, amount];
}