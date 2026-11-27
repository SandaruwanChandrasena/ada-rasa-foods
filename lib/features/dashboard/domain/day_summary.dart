import 'package:equatable/equatable.dart';

import '../../orders/domain/food_order.dart';
import '../../orders/domain/order_status.dart';

// One dish and how many were sold.
class TopDish extends Equatable {
  const TopDish({
    required this.dishId,
    required this.name,
    required this.quantity,
    this.imageUrl = '',
  });

  final String dishId;
  final String name;
  final int quantity;
  final String imageUrl;

  @override
  List<Object?> get props => [dishId, name, quantity, imageUrl];
}

const _soldStatuses = {OrderStatus.completed, OrderStatus.delivered};
const _droppedStatuses = {OrderStatus.rejected, OrderStatus.cancelled};

// The owner's numbers for one period (owner dashboard).
class DaySummary extends Equatable {
  const DaySummary({
    this.sales = 0,
    this.doneCount = 0,
    this.newCount = 0,
    this.activeCount = 0,
    this.droppedCount = 0,
    this.topDishes = const [],
  });

  // [open]: every order still going, from any day.
  // [ended]: ended orders, newest first. Only those placed at or
  // after [since] count.
  factory DaySummary.from({
    required List<FoodOrder> open,
    required List<FoodOrder> ended,
    required DateTime since,
    int maxTopDishes = 3,
  }) {
    final inPeriod = ended.where((o) => _placedSince(o, since)).toList();
    final sold = inPeriod.where((o) => _soldStatuses.contains(o.status));

    return DaySummary(
      sales: sold.fold(0, (sum, order) => sum + order.total),
      doneCount: sold.length,
      newCount: open.where((o) => o.status == OrderStatus.placed).length,
      activeCount: open.where((o) => o.status != OrderStatus.placed).length,
      droppedCount: inPeriod
          .where((o) => _droppedStatuses.contains(o.status))
          .length,
      topDishes: _topDishes(sold, maxTopDishes),
    );
  }

  // Whole rupees from completed orders only.
  final int sales;
  final int doneCount;
  final int newCount;
  final int activeCount;

  // Rejected or cancelled in the period.
  final int droppedCount;

  // Most sold first.
  final List<TopDish> topDishes;

  // An ended order always has a time. If not yet, it counts as now.
  static bool _placedSince(FoodOrder order, DateTime since) {
    final placedAt = order.placedAt;
    return placedAt == null || !placedAt.isBefore(since);
  }

  static List<TopDish> _topDishes(Iterable<FoodOrder> sold, int max) {
    final byId = <String, TopDish>{};
    for (final order in sold) {
      for (final item in order.items) {
        final old = byId[item.dishId];
        // The newest order comes first, so its name is kept.
        byId[item.dishId] = TopDish(
          dishId: item.dishId,
          name: old?.name ?? item.name,
          imageUrl: (old == null || old.imageUrl.isEmpty)
              ? item.imageUrl
              : old.imageUrl,
          quantity: (old?.quantity ?? 0) + item.quantity,
        );
      }
    }

    final dishes = byId.values.toList()
      ..sort((a, b) {
        final byQuantity = b.quantity.compareTo(a.quantity);
        return byQuantity != 0 ? byQuantity : a.name.compareTo(b.name);
      });
    return dishes.take(max).toList();
  }

  @override
  List<Object?> get props => [
        sales,
        doneCount,
        newCount,
        activeCount,
        droppedCount,
        topDishes,
      ];
}

// Sales of each of the last [days] days, oldest first, today last.
// Completed orders only (the dashboard chart).
List<int> salesByDay(List<FoodOrder> ended, DateTime now, {int days = 7}) {
  final today = DateTime.utc(now.year, now.month, now.day);
  final totals = List<int>.filled(days, 0);

  for (final order in ended) {
    final placedAt = order.placedAt;
    if (placedAt == null || !_soldStatuses.contains(order.status)) continue;

    // UTC dates, so a day is always 24 hours long.
    final day = DateTime.utc(placedAt.year, placedAt.month, placedAt.day);
    final daysAgo = today.difference(day).inDays;
    if (daysAgo >= 0 && daysAgo < days) {
      totals[days - 1 - daysAgo] += order.total;
    }
  }
  return totals;
}