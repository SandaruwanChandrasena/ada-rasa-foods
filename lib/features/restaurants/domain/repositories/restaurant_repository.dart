import '../entities/restaurant.dart';

// Streams send live updates. They report errors as DataFailure.
abstract class RestaurantRepository {
  // Restaurants with isActive true, for customers (CUS-1).
  Stream<List<Restaurant>> watchActiveRestaurants();

  // Emits null if the restaurant does not exist.
  Stream<Restaurant?> watchRestaurant(String restaurantId);
}