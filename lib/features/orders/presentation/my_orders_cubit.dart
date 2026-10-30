import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/data_failure.dart';
import '../domain/food_order.dart';
import '../domain/order_repository.dart';
import '../domain/order_status.dart';
import '../domain/seen_order_repository.dart';
import 'my_orders_state.dart';

// The customer's orders, live, for My orders and the home banner.
class MyOrdersCubit extends Cubit<MyOrdersState> {
  MyOrdersCubit(this._orderRepository, this._seenRepository)
      : super(const MyOrdersState());

  final OrderRepository _orderRepository;
  final SeenOrderRepository _seenRepository;

  StreamSubscription<List<FoodOrder>>? _subscription;
  String? _userId;

  // The home screen calls this. The same user again does nothing.
  Future<void> start(String userId, {bool force = false}) async {
    if (userId == _userId && !force) return;
    _userId = userId;

    await _subscription?.cancel();
    _subscription = null;
    emit(const MyOrdersState());

    final seen = await _seenRepository.loadSeen(userId);
    // Another user may have signed in while we waited.
    if (isClosed || userId != _userId) return;
    emit(MyOrdersState(seenIds: seen));

    _subscription = _orderRepository.watchCustomerOrders(userId).listen(
      (orders) {
        emit(
          MyOrdersState(
            status: MyOrdersStatus.loaded,
            orders: orders,
            seenIds: state.seenIds,
          ),
        );
      },
      onError: (Object error) {
        emit(
          MyOrdersState(
            status: MyOrdersStatus.failure,
            seenIds: state.seenIds,
            errorMessage: error is DataFailure
                ? error.message
                : 'Something went wrong. Please try again.',
          ),
        );
      },
    );
  }

  void retry() {
    final userId = _userId;
    if (userId != null) start(userId, force: true);
  }

  // Called when the customer opens an order. Hides its red banner.
  Future<void> markSeen(FoodOrder order) async {
    final userId = _userId;
    if (userId == null) return;
    if (order.status != OrderStatus.rejected) return;
    if (state.seenIds.contains(order.id)) return;

    emit(state.copyWith(seenIds: {...state.seenIds, order.id}));
    await _seenRepository.markSeen(userId, order.id);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}