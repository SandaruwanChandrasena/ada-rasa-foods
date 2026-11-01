import 'food_order.dart';
import 'order_status.dart';

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

  // Orders the restaurant still works on, oldest first (RES-1).
  Stream<List<FoodOrder>> watchRestaurantOpenOrders(String restaurantId);

  // The newest ended orders of the restaurant (RES-1 Done tab).
  Stream<List<FoodOrder>> watchRestaurantDoneOrders(String restaurantId);

  // A restaurant step, like accept or ready (RES-2, RES-5).
  // The payment changes too when needed.
  Future<void> moveOrder(FoodOrder order, OrderStatus next);
}