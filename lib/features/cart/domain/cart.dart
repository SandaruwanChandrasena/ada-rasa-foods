import 'package:equatable/equatable.dart';

import '../../menu/domain/dish.dart';
import 'cart_item.dart';

// The cart holds food from one restaurant only (CUS-3).
class Cart extends Equatable {
  const Cart({
    this.restaurantId = '',
    this.restaurantName = '',
    this.items = const [],
    this.updatedAt,
  });

  static const Cart empty = Cart();

  // Most of one dish a customer can add.
  static const int maxQuantity = 20;

  // The cart clears 1 day after the last change.
  static const Duration lifetime = Duration(days: 1);

  final String restaurantId;
  final String restaurantName;
  final List<CartItem> items;
  final DateTime? updatedAt;

  bool get isEmpty => items.isEmpty;

  // Number of dishes, counting amounts (2 kottu + 1 faluda = 3).
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  int get total => items.fold(0, (sum, item) => sum + item.lineTotal);

  int quantityOf(String dishId) {
    for (final item in items) {
      if (item.dishId == dishId) return item.quantity;
    }
    return 0;
  }

  bool canAddMore(String dishId) => quantityOf(dishId) < maxQuantity;

  // True when a dish comes from a different restaurant (CUS-13).
  bool isFromOtherRestaurant(String restaurantId) =>
      !isEmpty && this.restaurantId != restaurantId;

  // A cart with no change time is treated as old.
  bool isExpired(DateTime now) {
    final changed = updatedAt;
    return changed == null || now.difference(changed) > lifetime;
  }

  // Adds one of this dish. Clear the cart first for another restaurant.
  Cart addDish(
    Dish dish, {
    required String restaurantName,
    required DateTime now,
  }) {
    if (isFromOtherRestaurant(dish.restaurantId)) {
      throw StateError('The cart has food from another restaurant.');
    }

    final current = quantityOf(dish.id);
    if (current >= maxQuantity) return this;

    final newItems = current == 0
        ? [
            ...items,
            CartItem(
              dishId: dish.id,
              name: dish.name,
              price: dish.price,
              imageUrl: dish.imageUrl,
            ),
          ]
        : [
            for (final item in items)
              item.dishId == dish.id
                  ? item.copyWith(quantity: current + 1)
                  : item,
          ];

    return Cart(
      restaurantId: dish.restaurantId,
      restaurantName: restaurantName,
      items: newItems,
      updatedAt: now,
    );
  }

  // Sets the amount of one dish (0 to 20). Zero removes it.
  Cart setQuantity(String dishId, int quantity, {required DateTime now}) {
    if (quantityOf(dishId) == 0) return this;

    final amount = quantity.clamp(0, maxQuantity).toInt();
    final newItems = amount == 0
        ? items.where((item) => item.dishId != dishId).toList()
        : [
            for (final item in items)
              item.dishId == dishId ? item.copyWith(quantity: amount) : item,
          ];

    if (newItems.isEmpty) return empty;

    return Cart(
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      items: newItems,
      updatedAt: now,
    );
  }

  @override
  List<Object?> get props => [restaurantId, restaurantName, items, updatedAt];
}