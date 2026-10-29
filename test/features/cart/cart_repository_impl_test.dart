import 'dart:io';

import 'package:ada_rasa_foods/features/cart/data/cart_repository_impl.dart';
import 'package:ada_rasa_foods/features/cart/domain/cart.dart';
import 'package:ada_rasa_foods/features/cart/domain/cart_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

void main() {
  // A real Hive box in a temp folder, so we test the real saving.
  late Directory folder;
  late Box<dynamic> box;
  var now = DateTime(2026, 10, 29, 10);

  final cart = Cart(
    restaurantId: 'r1',
    restaurantName: 'Kottu Corner',
    items: const [
      CartItem(dishId: 'd1', name: 'Chicken Kottu', price: 1200, quantity: 2),
      CartItem(dishId: 'd2', name: 'Iced Milo', price: 450),
    ],
    updatedAt: DateTime(2026, 10, 29, 9),
  );

  CartRepositoryImpl repository() => CartRepositoryImpl(box, clock: () => now);

  setUp(() async {
    now = DateTime(2026, 10, 29, 10);
    folder = await Directory.systemTemp.createTemp('ada_rasa_cart_test');
    Hive.init(folder.path);
    box = await Hive.openBox<dynamic>(CartRepositoryImpl.boxName);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (folder.existsSync()) await folder.delete(recursive: true);
  });

  test('no saved cart gives an empty cart', () async {
    expect(await repository().loadCart('u1'), Cart.empty);
  });

  test('a saved cart comes back the same after the app restarts', () async {
    await repository().saveCart('u1', cart);

    // Close and open the box again, like closing and opening the app.
    await box.close();
    box = await Hive.openBox<dynamic>(CartRepositoryImpl.boxName);

    expect(await repository().loadCart('u1'), cart);
  });

  test('each user has their own cart', () async {
    await repository().saveCart('u1', cart);

    expect(await repository().loadCart('u2'), Cart.empty);
    expect(await repository().loadCart('u1'), cart);
  });

  test('a cart older than 1 day is cleared', () async {
    await repository().saveCart('u1', cart);
    now = cart.updatedAt!.add(const Duration(hours: 25));

    expect(await repository().loadCart('u1'), Cart.empty);
    expect(box.containsKey('u1'), isFalse);
  });

  test('clearCart deletes the saved cart', () async {
    await repository().saveCart('u1', cart);
    await repository().clearCart('u1');

    expect(box.containsKey('u1'), isFalse);
  });

  test('saving an empty cart deletes the saved cart', () async {
    await repository().saveCart('u1', cart);
    await repository().saveCart('u1', Cart.empty);

    expect(box.containsKey('u1'), isFalse);
  });

  test('broken saved data gives an empty cart', () async {
    await box.put('u1', 'not a cart');

    expect(await repository().loadCart('u1'), Cart.empty);
  });

  test('broken items are dropped', () async {
    await box.put('u1', {
      'restaurantId': 'r1',
      'restaurantName': 'Kottu Corner',
      'updatedAt': DateTime(2026, 10, 29, 9).millisecondsSinceEpoch,
      'items': [
        {'dishId': 'd1', 'name': 'Chicken Kottu', 'price': 1200, 'quantity': 1},
        {'dishId': '', 'name': 'No id', 'price': 100, 'quantity': 1},
        {'dishId': 'd3', 'name': 'Zero', 'price': 100, 'quantity': 0},
        'not a map',
      ],
    });

    final loaded = await repository().loadCart('u1');
    expect(loaded.items.map((item) => item.dishId), ['d1']);
  });
}