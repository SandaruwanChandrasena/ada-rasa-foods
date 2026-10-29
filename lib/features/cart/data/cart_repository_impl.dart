import 'package:hive_ce/hive_ce.dart';

import '../domain/cart.dart';
import '../domain/cart_item.dart';
import '../domain/cart_repository.dart';

// Saves carts in a Hive box. The key is the user id.
class CartRepositoryImpl implements CartRepository {
  CartRepositoryImpl(this._box, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  // The box is opened once when the app starts.
  static const String boxName = 'carts';

  final Box<dynamic> _box;

  // Tests can pass a fixed time here.
  final DateTime Function() _clock;

  @override
  Future<Cart> loadCart(String userId) async {
    final data = _box.get(userId);
    if (data is! Map) return Cart.empty;

    final cart = _fromMap(data);
    if (cart.isEmpty || cart.isExpired(_clock())) {
      await _box.delete(userId);
      return Cart.empty;
    }
    return cart;
  }

  @override
  Future<void> saveCart(String userId, Cart cart) async {
    if (cart.isEmpty) {
      await _box.delete(userId);
      return;
    }
    await _box.put(userId, _toMap(cart));
  }

  @override
  Future<void> clearCart(String userId) => _box.delete(userId);

  // Hive saves plain maps, so we need no type adapters or code generation.
  Map<String, dynamic> _toMap(Cart cart) {
    return {
      'restaurantId': cart.restaurantId,
      'restaurantName': cart.restaurantName,
      'updatedAt': cart.updatedAt?.millisecondsSinceEpoch,
      'items': [
        for (final item in cart.items)
          {
            'dishId': item.dishId,
            'name': item.name,
            'price': item.price,
            'imageUrl': item.imageUrl,
            'quantity': item.quantity,
          },
      ],
    };
  }

  Cart _fromMap(Map<dynamic, dynamic> data) {
    final rawItems = data['items'];
    final items = <CartItem>[
      if (rawItems is List)
        for (final raw in rawItems)
          if (raw is Map)
            CartItem(
              dishId: _text(raw['dishId']),
              name: _text(raw['name']),
              price: _number(raw['price']),
              imageUrl: _text(raw['imageUrl']),
              quantity: _number(raw['quantity'])
                  .clamp(0, Cart.maxQuantity)
                  .toInt(),
            ),
    ];

    // Drop broken items.
    items.removeWhere((item) => item.dishId.isEmpty || item.quantity == 0);

    final millis = data['updatedAt'];
    return Cart(
      restaurantId: _text(data['restaurantId']),
      restaurantName: _text(data['restaurantName']),
      items: items,
      updatedAt:
          millis is int ? DateTime.fromMillisecondsSinceEpoch(millis) : null,
    );
  }

  String _text(Object? value) => value is String ? value : '';

  int _number(Object? value) => value is num ? value.toInt() : 0;
}