import 'package:equatable/equatable.dart';

import '../../orders/domain/food_order.dart';
import '../../orders/domain/order_status.dart';

// One dish and how many were sold today.
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

// The owner's numbers for today (owner dashboard).
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
  // [endedToday]: ended orders placed today, newest first.
  factory DaySummary.from({
    required List<FoodOrder> open,
    required List<FoodOrder> endedToday,
  }) {
    final sold = endedToday.where((o) => _soldStatuses.contains(o.status));

    return DaySummary(
      sales: sold.fold(0, (sum, order) => sum + order.total),
      doneCount: sold.length,
      newCount: open.where((o) => o.status == OrderStatus.placed).length,
      activeCount: open.where((o) => o.status != OrderStatus.placed).length,
      droppedCount: endedToday
          .where((o) => _droppedStatuses.contains(o.status))
          .length,
      topDishes: _topDishes(sold),
    );
  }

  static const int maxTopDishes = 3;

  static const _soldStatuses = {OrderStatus.completed, OrderStatus.delivered};
  static const _droppedStatuses = {
    OrderStatus.rejected,
    OrderStatus.cancelled,
  };

  // Whole rupees from completed orders only.
  final int sales;
  final int doneCount;
  final int newCount;
  final int activeCount;

  // Rejected or cancelled today.
  final int droppedCount;

  // Most sold first. At most [maxTopDishes].
  final List<TopDish> topDishes;

  static List<TopDish> _topDishes(Iterable<FoodOrder> sold) {
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
    return dishes.take(maxTopDishes).toList();
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