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

  // The newest rejected order the customer has not opened yet.
  FoodOrder? get unseenRejected {
    for (final order in orders) {
      if (order.status == OrderStatus.rejected &&
          !seenIds.contains(order.id)) {
        return order;
      }
    }
    return null;
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