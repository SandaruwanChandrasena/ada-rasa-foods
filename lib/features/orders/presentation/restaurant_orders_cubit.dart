import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/data_failure.dart';
import '../domain/food_order.dart';
import '../domain/order_repository.dart';
import '../domain/order_status.dart';
import 'restaurant_orders_state.dart';

// The restaurant's orders, live, and the status steps (RES-1, RES-2).
class RestaurantOrdersCubit extends Cubit<RestaurantOrdersState> {
  RestaurantOrdersCubit(this._orderRepository)
      : super(const RestaurantOrdersState());

  final OrderRepository _orderRepository;

  StreamSubscription<List<FoodOrder>>? _openSubscription;
  StreamSubscription<List<FoodOrder>>? _doneSubscription;
  String? _restaurantId;

  // Placed orders we already know. Null until the first load.
  Set<String>? _knownNewIds;

  // Starts (or restarts) watching. The Retry button also calls this.
  Future<void> start(String restaurantId) async {
    _restaurantId = restaurantId;
    await _stop();
    _knownNewIds = null;
    emit(const RestaurantOrdersState());

    _openSubscription = _orderRepository
        .watchRestaurantOpenOrders(restaurantId)
        .listen(_onOpen, onError: _onError);
    _doneSubscription = _orderRepository
        .watchRestaurantDoneOrders(restaurantId)
        .listen(
          (done) => emit(state.copyWith(done: done, doneLoaded: true)),
          onError: _onError,
        );
  }

  void retry() {
    final restaurantId = _restaurantId;
    if (restaurantId != null) start(restaurantId);
  }

  void _onOpen(List<FoodOrder> open) {
    final newIds = {
      for (final order in open)
        if (order.status == OrderStatus.placed) order.id,
    };

    // No alert on the first load. Only for orders that arrive later.
    final known = _knownNewIds;
    final arrived = known == null
        ? const <FoodOrder>[]
        : open.where(
            (o) => o.status == OrderStatus.placed && !known.contains(o.id),
          ).toList();
    _knownNewIds = {...?known, ...newIds};

    emit(
      state.copyWith(
        view: BoardView.loaded,
        open: open,
        newOrderNumber: arrived.isEmpty ? null : arrived.last.shortNumber,
        newOrderAlertId: arrived.isEmpty
            ? state.newOrderAlertId
            : state.newOrderAlertId + 1,
      ),
    );
  }

  void _onError(Object error) {
    emit(
      RestaurantOrdersState(
        view: BoardView.failure,
        errorMessage: error is DataFailure
            ? error.message
            : 'Something went wrong. Please try again.',
      ),
    );
  }

  // Accept, reject, preparing, ready, or completed.
  Future<void> move(FoodOrder order, OrderStatus next) async {
    if (state.isBusy(order)) return;
    emit(state.copyWith(busyIds: {...state.busyIds, order.id}));

    String message;
    try {
      await _orderRepository.moveOrder(order, next);
      final label = next.labelFor(order.fulfillment).toLowerCase();
      message = 'Order #${order.shortNumber} is now $label.';
    } catch (error) {
      message = error is DataFailure
          ? error.message
          : 'Something went wrong. Please try again.';
    }

    if (isClosed) return;
    // The live lists show the new status. Here we only show a message.
    emit(
      state.copyWith(
        busyIds: {...state.busyIds}..remove(order.id),
        notice: message,
        noticeId: state.noticeId + 1,
      ),
    );
  }

  Future<void> _stop() async {
    await _openSubscription?.cancel();
    await _doneSubscription?.cancel();
    _openSubscription = null;
    _doneSubscription = null;
  }

  @override
  Future<void> close() async {
    await _stop();
    return super.close();
  }
}