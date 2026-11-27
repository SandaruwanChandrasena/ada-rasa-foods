import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/data_failure.dart';
import '../../orders/domain/food_order.dart';
import '../../orders/domain/order_repository.dart';
import '../domain/day_summary.dart';
import 'owner_dashboard_state.dart';

// Today's numbers for the owner, live. Starts again at midnight.
class OwnerDashboardCubit extends Cubit<OwnerDashboardState> {
  OwnerDashboardCubit(this._orderRepository, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(const OwnerDashboardState());

  final OrderRepository _orderRepository;

  // Tests give a fake clock.
  final DateTime Function() _now;

  StreamSubscription<List<FoodOrder>>? _openSubscription;
  StreamSubscription<List<FoodOrder>>? _endedSubscription;
  Timer? _midnightTimer;
  String? _restaurantId;

  // Null until each list arrives the first time.
  List<FoodOrder>? _open;
  List<FoodOrder>? _endedToday;

  // Starts (or restarts) watching. The Retry button also calls this.
  Future<void> start(String restaurantId) async {
    _restaurantId = restaurantId;
    await _stop();
    _open = null;
    _endedToday = null;
    emit(const OwnerDashboardState());

    _openSubscription = _orderRepository
        .watchRestaurantOpenOrders(restaurantId)
        .listen((open) {
          _open = open;
          _emitSummary();
        }, onError: _onError);
    _watchToday(restaurantId);
  }

  void retry() {
    final restaurantId = _restaurantId;
    if (restaurantId != null) start(restaurantId);
  }

  // The timer calls this at midnight, so today starts from zero.
  Future<void> newDay() async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || isClosed) return;
    await _endedSubscription?.cancel();
    _watchToday(restaurantId);
  }

  // A small margin, so the timer surely fires on the new day.
  static Duration untilMidnight(DateTime now) {
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now) + const Duration(seconds: 1);
  }

  void _watchToday(String restaurantId) {
    final now = _now();
    final since = DateTime(now.year, now.month, now.day);

    _endedSubscription = _orderRepository
        .watchRestaurantEndedSince(restaurantId, since)
        .listen((ended) {
          _endedToday = ended;
          _emitSummary();
        }, onError: _onError);

    _midnightTimer?.cancel();
    _midnightTimer = Timer(untilMidnight(now), newDay);
  }

  void _emitSummary() {
    final open = _open;
    final endedToday = _endedToday;
    if (open == null || endedToday == null || isClosed) return;

    final now = _now();
    emit(
      OwnerDashboardState(
        view: DashboardView.loaded,
        summary: DaySummary.from(
          open: open,
          ended: endedToday,
          since: DateTime(now.year, now.month, now.day),
        ),
      ),
    );
  }

  void _onError(Object error) {
    if (isClosed) return;
    emit(
      OwnerDashboardState(
        view: DashboardView.failure,
        errorMessage: error is DataFailure
            ? error.message
            : 'Something went wrong. Please try again.',
      ),
    );
  }

  Future<void> _stop() async {
    _midnightTimer?.cancel();
    _midnightTimer = null;
    await _openSubscription?.cancel();
    await _endedSubscription?.cancel();
    _openSubscription = null;
    _endedSubscription = null;
  }

  @override
  Future<void> close() async {
    await _stop();
    return super.close();
  }
}