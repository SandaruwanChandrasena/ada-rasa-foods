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

  // The owner changes the restaurant photo. Empty removes it (RES-3).
  Future<void> setImageUrl(String restaurantId, String imageUrl);

  // The owner changes the shop details. Phone is digits only, or empty.
  // The address stays with the admin, because it goes with the map point.
  Future<void> updateDetails(
    String restaurantId, {
    required String name,
    required String cuisine,
    required String phone,
    required String description,
  });
}