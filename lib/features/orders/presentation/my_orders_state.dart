import 'package:equatable/equatable.dart';

import '../domain/food_order.dart';
import '../domain/order_status.dart';

enum MyOrdersStatus { loading, loaded, failure }

class MyOrdersState extends Equatable {
  const MyOrdersState({
    this.status = MyOrdersStatus.loading,
    this.orders = const [],
    this.seenIds = const {},
    this.errorMessage,
  });

  final MyOrdersStatus status;

  // Newest first.
  final List<FoodOrder> orders;

  // Rejected orders the customer already opened.
  final Set<String> seenIds;

  final String? errorMessage;

  // Orders that are not finished yet (Placed to Ready for pickup).
  List<FoodOrder> get activeOrders =>
      orders.where((order) => !order.status.isEnd).toList();

  // A rejection older than this is old news, so no red banner.
  static const rejectedNewsTime = Duration(hours: 24);

  // Rejected in the last 24 hours, and not opened yet. Newest first.
  List<FoodOrder> get unseenRejectedOrders {
    final now = DateTime.now();
    return orders.where((order) {
      if (order.status != OrderStatus.rejected) return false;
      if (seenIds.contains(order.id)) return false;
      // Null while the server time is on its way, so it counts as new.
      final at = order.updatedAt ?? order.placedAt;
      return at == null || now.difference(at) < rejectedNewsTime;
    }).toList();
  }

  // The order for the red home banner.
  FoodOrder? get unseenRejected {
    final list = unseenRejectedOrders;
    return list.isEmpty ? null : list.first;
  }

  MyOrdersState copyWith({Set<String>? seenIds}) {
    return MyOrdersState(
      status: status,
      orders: orders,
      seenIds: seenIds ?? this.seenIds,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        orders,
        // A sorted list, so two sets with the same ids are equal.
        seenIds.toList()..sort(),
        errorMessage,
      ];
}