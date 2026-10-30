import 'package:equatable/equatable.dart';

import '../../cart/domain/cart_item.dart';

// A copy of one dish, so old orders stay correct if the menu changes.
class OrderItem extends Equatable {
  const OrderItem({
    required this.dishId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl = '',
  });

  factory OrderItem.fromCartItem(CartItem item) {
    return OrderItem(
      dishId: item.dishId,
      name: item.name,
      price: item.price,
      quantity: item.quantity,
      imageUrl: item.imageUrl,
    );
  }

  final String dishId;
  final String name;

  // Whole rupees for one dish, at the time of the order.
  final int price;

  final int quantity;
  final String imageUrl;

  int get lineTotal => price * quantity;

  @override
  List<Object?> get props => [dishId, name, price, quantity, imageUrl];
}