import 'restaurant.dart';

// Streams send live updates. They report errors as DataFailure.
// Futures throw DataFailure.
abstract class RestaurantRepository {
  // Restaurants with isActive true, for customers (CUS-1).
  Stream<List<Restaurant>> watchActiveRestaurants();

  // Emits null if the restaurant does not exist.
  Stream<Restaurant?> watchRestaurant(String restaurantId);

  // The owner opens or closes the restaurant (RES-4).
  Future<void> setOpen(String restaurantId, {required bool isOpen});
}