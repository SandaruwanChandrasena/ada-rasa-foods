import '../domain/dish.dart';

// Turns a restaurants/{id}/menuItems/{itemId} document into a Dish,
// and back.
class DishModel {
  const DishModel._();

  // Missing fields get safe defaults. No "available" field means not orderable.
  static Dish fromMap(
    String id,
    String restaurantId,
    Map<String, dynamic> map,
  ) {
    return Dish(
      id: id,
      restaurantId: restaurantId,
      name: map['name'] as String? ?? '',
      // Works even if a price was typed as 1200.0 in the console.
      price: (map['price'] as num?)?.toInt() ?? 0,
      category: map['category'] as String? ?? '',
      description: map['description'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      available: map['available'] as bool? ?? false,
    );
  }

  // Exactly the fields the Firestore rules allow (isValidMenuItem).
  static Map<String, dynamic> toMap(Dish dish) {
    return {
      'name': dish.name,
      'description': dish.description,
      'price': dish.price,
      'imageUrl': dish.imageUrl,
      'category': dish.category,
      'available': dish.available,
    };
  }
}