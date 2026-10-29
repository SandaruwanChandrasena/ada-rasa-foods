import 'cart.dart';

// Saves each user's cart on this phone. Each user has their own cart.
abstract class CartRepository {
  // Gives an empty cart if there is none, or if it is older than 1 day.
  Future<Cart> loadCart(String userId);

  Future<void> saveCart(String userId, Cart cart);

  Future<void> clearCart(String userId);
}