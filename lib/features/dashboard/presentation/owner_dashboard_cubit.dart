import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/data_failure.dart';
import '../../orders/domain/food_order.dart';
import '../../orders/domain/order_repository.dart';
import '../domain/dash_period.dart';
import '../domain/day_summary.dart';
import 'owner_dashboard_state.dart';

// The owner's numbers, live. Loads the last 30 days once, so the
// period switch needs no new read. Starts again at midnight.
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
  DashPeriod _period = DashPeriod.today;

  // Null until each list arrives the first time.
  List<FoodOrder>? _open;
  List<FoodOrder>? _ended;

  // Starts (or restarts) watching. The Retry button also calls this.
  Future<void> start(String restaurantId) async {
    _restaurantId = restaurantId;
    await _stop();
    _open = null;
    _ended = null;
    emit(OwnerDashboardState(period: _period));

    _openSubscription = _orderRepository
        .watchRestaurantOpenOrders(restaurantId)
        .listen((open) {
          _open = open;
          _emitSummary();
        }, onError: _onError);
    _watchEnded(restaurantId);
  }

  void retry() {
    final restaurantId = _restaurantId;
    if (restaurantId != null) start(restaurantId);
  }

  // Today, 7 days or 30 days. Uses the orders already loaded.
  void pickPeriod(DashPeriod period) {
    if (period == _period) return;
    _period = period;
    if (_open != null && _ended != null) {
      _emitSummary();
    } else {
      emit(
        OwnerDashboardState(
          view: state.view,
          period: period,
          errorMessage: state.errorMessage,
        ),
      );
    }
  }

  // The timer calls this at midnight, so the days move on.
  Future<void> newDay() async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || isClosed) return;
    await _endedSubscription?.cancel();
    _watchEnded(restaurantId);
    _emitSummary();
  }

  // A small margin, so the timer surely fires on the new day.
  static Duration untilMidnight(DateTime now) {
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now) + const Duration(seconds: 1);
  }

  void _watchEnded(String restaurantId) {
    final now = _now();

    _endedSubscription = _orderRepository
        .watchRestaurantEndedSince(restaurantId, DashPeriod.longest.since(now))
        .listen((ended) {
          _ended = ended;
          _emitSummary();
        }, onError: _onError);

    _midnightTimer?.cancel();
    _midnightTimer = Timer(untilMidnight(now), newDay);
  }

  void _emitSummary() {
    final open = _open;
    final ended = _ended;
    if (open == null || ended == null || isClosed) return;

    final now = _now();
    emit(
      OwnerDashboardState(
        view: DashboardView.loaded,
        period: _period,
        summary: DaySummary.from(
          open: open,
          ended: ended,
          since: _period.since(now),
          maxTopDishes: _period.maxTopDishes,
        ),
        weekSales: salesByDay(ended, now),
        today: DateTime(now.year, now.month, now.day),
      ),
    );
  }

  void _onError(Object error) {
    if (isClosed) return;
    emit(
      OwnerDashboardState(
        view: DashboardView.failure,
        period: _period,
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