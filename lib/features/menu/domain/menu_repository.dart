import 'dish.dart';

// Streams send live updates. They report errors as DataFailure.
// Futures throw DataFailure.
abstract class MenuRepository {
  // All items of one restaurant, including not available ones (CUS-2).
  Stream<List<Dish>> watchMenu(String restaurantId);

  // The owner adds a dish (RES-3). Gives back the new id.
  Future<String> addDish(Dish dish);

  // The owner saves changes to a dish (RES-3).
  Future<void> updateDish(Dish dish);

  // The owner deletes a dish. Old orders keep their own copies.
  Future<void> deleteDish(Dish dish);

  // The Available switch on the menu screen (RES-3).
  Future<void> setAvailable(Dish dish, {required bool available});
}