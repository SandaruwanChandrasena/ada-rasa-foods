import 'package:ada_rasa_foods/features/cart/domain/cart.dart';
import 'package:ada_rasa_foods/features/cart/domain/cart_item.dart';
import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:flutter_test/flutter_test.dart';

Dish dish(String id, int price, {String restaurantId = 'r1'}) {
  return Dish(
    id: id,
    restaurantId: restaurantId,
    name: 'Dish $id',
    price: price,
    category: 'Kottu',
  );
}

void main() {
  final now = DateTime(2026, 10, 29, 10);
  final kottu = dish('d1', 1200);
  final milo = dish('d2', 450);

  Cart addTimes(Cart cart, Dish item, int times) {
    var result = cart;
    for (var i = 0; i < times; i++) {
      result = result.addDish(item, restaurantName: 'Kottu Corner', now: now);
    }
    return result;
  }

  test('an empty cart has no items and no total', () {
    expect(Cart.empty.isEmpty, isTrue);
    expect(Cart.empty.itemCount, 0);
    expect(Cart.empty.total, 0);
  });

  test('addDish adds one dish and keeps the restaurant', () {
    final cart = addTimes(Cart.empty, kottu, 1);

    expect(cart.items, [
      const CartItem(dishId: 'd1', name: 'Dish d1', price: 1200),
    ]);
    expect(cart.restaurantId, 'r1');
    expect(cart.restaurantName, 'Kottu Corner');
    expect(cart.updatedAt, now);
  });

  test('adding the same dish again raises the amount', () {
    final cart = addTimes(Cart.empty, kottu, 2);

    expect(cart.items.length, 1);
    expect(cart.quantityOf('d1'), 2);
  });

  test('itemCount and total add up all dishes', () {
    final cart = addTimes(addTimes(Cart.empty, kottu, 2), milo, 1);

    expect(cart.itemCount, 3);
    expect(cart.total, 2 * 1200 + 450);
  });

  test('a dish from another restaurant is not allowed', () {
    final cart = addTimes(Cart.empty, kottu, 1);
    final other = dish('d9', 900, restaurantId: 'r2');

    expect(cart.isFromOtherRestaurant('r2'), isTrue);
    expect(
      () => cart.addDish(other, restaurantName: 'Pizza', now: now),
      throwsStateError,
    );
  });

  test('an empty cart takes food from any restaurant', () {
    expect(Cart.empty.isFromOtherRestaurant('r2'), isFalse);
  });

  test('one dish stops at 20', () {
    final cart = addTimes(Cart.empty, kottu, 25);

    expect(cart.quantityOf('d1'), Cart.maxQuantity);
    expect(cart.canAddMore('d1'), isFalse);
  });

  group('setQuantity', () {
    final cart = addTimes(addTimes(Cart.empty, kottu, 2), milo, 1);

    test('changes the amount', () {
      expect(cart.setQuantity('d1', 5, now: now).quantityOf('d1'), 5);
    });

    test('keeps the amount between 0 and 20', () {
      expect(cart.setQuantity('d1', 99, now: now).quantityOf('d1'), 20);
    });

    test('zero removes the dish', () {
      final result = cart.setQuantity('d1', 0, now: now);
      expect(result.quantityOf('d1'), 0);
      expect(result.items.length, 1);
    });

    test('removing the last dish gives an empty cart', () {
      final one = addTimes(Cart.empty, kottu, 1);
      expect(one.setQuantity('d1', 0, now: now), Cart.empty);
    });

    test('a dish not in the cart changes nothing', () {
      expect(cart.setQuantity('nope', 3, now: now), cart);
    });
  });

  group('isExpired (1-day rule)', () {
    final cart = addTimes(Cart.empty, kottu, 1);

    test('is false within 1 day', () {
      expect(cart.isExpired(now.add(const Duration(hours: 23))), isFalse);
    });

    test('is true after more than 1 day', () {
      expect(cart.isExpired(now.add(const Duration(hours: 25))), isTrue);
    });

    test('a cart with no change time counts as old', () {
      expect(const Cart().isExpired(now), isTrue);
    });
  });

  test('itemCountWithout and totalWithout skip the given dishes', () {
    final cart = addTimes(addTimes(Cart.empty, kottu, 2), milo, 1);

    expect(cart.itemCountWithout({'d1'}), 1);
    expect(cart.totalWithout({'d1'}), 450);
  });

  group('withMenuDetails', () {
    final cart = addTimes(Cart.empty, kottu, 2);

    test('uses the new price from the menu and keeps updatedAt', () {
      final result = cart.withMenuDetails([dish('d1', 1300)]);

      expect(result.items.single.price, 1300);
      expect(result.items.single.quantity, 2);
      expect(result.total, 2600);
      expect(result.updatedAt, cart.updatedAt);
    });

    test('gives back the same cart when nothing changed', () {
      expect(identical(cart.withMenuDetails([kottu]), cart), isTrue);
    });

    test('keeps a dish that is missing from the menu', () {
      expect(cart.withMenuDetails(const []), cart);
    });
  });
}