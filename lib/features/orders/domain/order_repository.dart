import 'food_order.dart';

// Futures throw DataFailure. Streams report errors as DataFailure.
abstract class OrderRepository {
  // Saves a new order and gives back its id (CUS-4).
  Future<String> placeOrder(FoodOrder order);

  // Live updates for the order status screen (CUS-11).
  // Emits null if the order does not exist.
  Stream<FoodOrder?> watchOrder(String orderId);

  // The customer's orders, newest first (My orders).
  Stream<List<FoodOrder>> watchCustomerOrders(String customerId);

  // Only while placed. A paid card order becomes refunded.
  Future<void> cancelOrder(FoodOrder order);
}