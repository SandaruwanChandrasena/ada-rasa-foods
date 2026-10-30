import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/data_failure.dart';
import '../domain/food_order.dart';
import '../domain/order_repository.dart';
import 'order_status_state.dart';

// One order, live, with cancel while placed (CUS-11, CUS-6).
class OrderStatusCubit extends Cubit<OrderStatusState> {
  OrderStatusCubit(this._orderRepository) : super(const OrderStatusState());

  final OrderRepository _orderRepository;

  StreamSubscription<FoodOrder?>? _subscription;
  String? _orderId;

  // Starts (or restarts) watching. The Retry button also calls this.
  void start(String orderId) {
    _orderId = orderId;
    _subscription?.cancel();
    emit(const OrderStatusState());

    _subscription = _orderRepository.watchOrder(orderId).listen(
      (order) {
        emit(
          order == null
              ? const OrderStatusState(view: OrderView.notFound)
              : state.copyWith(view: OrderView.loaded, order: order),
        );
      },
      onError: (Object error) {
        emit(
          OrderStatusState(
            view: OrderView.failure,
            errorMessage: error is DataFailure
                ? error.message
                : 'Something went wrong. Please try again.',
          ),
        );
      },
    );
  }

  void retry() {
    final orderId = _orderId;
    if (orderId != null) start(orderId);
  }

  Future<void> cancel() async {
    final order = state.order;
    if (order == null || !state.canCancel) return;

    emit(state.copyWith(isCancelling: true));

    String message;
    try {
      await _orderRepository.cancelOrder(order);
      message = 'Your order is cancelled.';
    } catch (error) {
      message = error is DataFailure
          ? error.message
          : 'Something went wrong. Please try again.';
    }

    if (isClosed) return;
    // The live stream shows the new status. Here we only show a message.
    emit(
      state.copyWith(
        isCancelling: false,
        notice: message,
        noticeId: state.noticeId + 1,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}