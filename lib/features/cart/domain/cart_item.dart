import 'package:equatable/equatable.dart';

// One dish in the cart. Name, price, and image are copies from the menu.
class CartItem extends Equatable {
  const CartItem({
    required this.dishId,
    required this.name,
    required this.price,
    this.imageUrl = '',
    this.quantity = 1,
  });

  final String dishId;
  final String name;

  // Whole rupees for one dish.
  final int price;

  final String imageUrl;
  final int quantity;

  int get lineTotal => price * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      dishId: dishId,
      name: name,
      price: price,
      imageUrl: imageUrl,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  List<Object?> get props => [dishId, name, price, imageUrl, quantity];
}