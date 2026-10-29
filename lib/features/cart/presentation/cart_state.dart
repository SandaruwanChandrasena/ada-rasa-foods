import 'package:equatable/equatable.dart';

import '../domain/cart.dart';

class CartState extends Equatable {
  const CartState({
    this.userId,
    this.cart = Cart.empty,
    this.isLoading = false,
  });

  // The signed-in customer. Null means no cart (signed out or not a customer).
  final String? userId;

  final Cart cart;

  // True while the saved cart is read from the phone.
  final bool isLoading;

  CartState copyWith({Cart? cart}) {
    return CartState(
      userId: userId,
      cart: cart ?? this.cart,
      isLoading: isLoading,
    );
  }

  @override
  List<Object?> get props => [userId, cart, isLoading];
}