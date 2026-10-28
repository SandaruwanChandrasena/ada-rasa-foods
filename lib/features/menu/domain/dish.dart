import 'package:equatable/equatable.dart';

// One food item on a restaurant menu. Saved in restaurants/{id}/menuItems.
class Dish extends Equatable {
  const Dish({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.price,
    required this.category,
    this.description = '',
    this.imageUrl = '',
    this.available = true,
  });

  final String id;

  // The restaurant this item belongs to. Used by the cart rule (CUS-3).
  final String restaurantId;

  final String name;

  // Whole rupees, like 1200 for Rs. 1,200.
  final int price;

  final String category;
  final String description;

  // Empty means the app shows the default image.
  final String imageUrl;

  final bool available;

  bool get hasImage => imageUrl.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        restaurantId,
        name,
        price,
        category,
        description,
        imageUrl,
        available,
      ];
}