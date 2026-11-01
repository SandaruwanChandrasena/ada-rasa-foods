import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/payment_card.dart';
import 'payment_state.dart';

// Fake card payment (CUS-10): waits, then says approved or declined.
// The card ending in 0002 is always declined.
class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit({this._processingTime = defaultProcessingTime})
      : super(const PaymentState());

  static const defaultProcessingTime = Duration(seconds: 2);

  final Duration _processingTime;

  // Gives true when the payment is approved.
  Future<bool> pay({required PaymentCard card, required int amount}) async {
    // A second tap must never start a second payment.
    if (state.isProcessing) return false;

    emit(
      PaymentState(
        status: DemoPaymentStatus.processing,
        card: card,
        amount: amount,
      ),
    );

    await Future<void>.delayed(_processingTime);

    // The customer may leave the screen while we wait.
    if (isClosed) return false;

    final approved = !card.alwaysFails;
    emit(
      PaymentState(
        status: approved
            ? DemoPaymentStatus.approved
            : DemoPaymentStatus.declined,
        card: card,
        amount: amount,
      ),
    );
    return approved;
  }

  // Back to the start, for "Try another card". Not while processing.
  void reset() {
    if (state.isProcessing || state.status == DemoPaymentStatus.idle) {
      return;
    }
    emit(const PaymentState());
  }
}