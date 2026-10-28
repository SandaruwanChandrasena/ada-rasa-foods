import '../entities/dish.dart';

// Streams send live updates. They report errors as DataFailure.
abstract class MenuRepository {
  // All items of one restaurant, including not available ones (CUS-2).
  Stream<List<Dish>> watchMenu(String restaurantId);
}