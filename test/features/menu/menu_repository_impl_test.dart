import 'package:ada_rasa_foods/features/menu/data/menu_repository_impl.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MenuRepositoryImpl repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = MenuRepositoryImpl(firestore);
  });

  Future<void> addDish(
    String restaurantId,
    String id, {
    required String name,
    required String category,
    num price = 1000,
  }) {
    return firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('menuItems')
        .doc(id)
        .set({
          'name': name,
          'description': 'Tasty food.',
          'price': price,
          'imageUrl': '',
          'category': category,
          'available': true,
        });
  }

  group('watchMenu', () {
    test('groups dishes by category, then sorts A to Z', () async {
      await addDish('r1', 'd1', name: 'Iced Milo', category: 'Drinks');
      await addDish('r1', 'd2', name: 'Egg Kottu', category: 'Kottu');
      await addDish('r1', 'd3', name: 'Cheese Kottu', category: 'Kottu');

      final dishes = await repository.watchMenu('r1').first;

      expect(
        dishes.map((d) => d.name),
        ['Iced Milo', 'Cheese Kottu', 'Egg Kottu'],
      );
    });

    test('shows only the dishes of the asked restaurant', () async {
      await addDish('r1', 'd1', name: 'Chicken Kottu', category: 'Kottu');
      await addDish('r2', 'd2', name: 'Cheese Pizza', category: 'Pizza');

      final dishes = await repository.watchMenu('r1').first;

      expect(dishes.map((d) => d.id), ['d1']);
    });

    test('sets the restaurantId on every dish', () async {
      await addDish('r1', 'd1', name: 'Chicken Kottu', category: 'Kottu');

      final dishes = await repository.watchMenu('r1').first;

      expect(dishes.single.restaurantId, 'r1');
    });

    test('reads all fields correctly', () async {
      await addDish(
        'r1',
        'd1',
        name: 'Chicken Kottu',
        category: 'Kottu',
        price: 1200,
      );

      final dish = (await repository.watchMenu('r1').first).single;

      expect(dish.name, 'Chicken Kottu');
      expect(dish.price, 1200);
      expect(dish.category, 'Kottu');
      expect(dish.description, 'Tasty food.');
      expect(dish.available, isTrue);
      expect(dish.hasImage, isFalse);
    });

    test('reads a decimal price like 1200.0 as 1200', () async {
      await addDish(
        'r1',
        'd1',
        name: 'Chicken Kottu',
        category: 'Kottu',
        price: 1200.0,
      );

      final dish = (await repository.watchMenu('r1').first).single;

      expect(dish.price, 1200);
    });

    test('missing fields get safe defaults: not available', () async {
      await firestore
          .collection('restaurants')
          .doc('r1')
          .collection('menuItems')
          .doc('d1')
          .set({'name': 'Mystery Dish'});

      final dish = (await repository.watchMenu('r1').first).single;

      expect(dish.available, isFalse);
      expect(dish.price, 0);
      expect(dish.category, '');
      expect(dish.description, '');
    });

    test('gives an empty list when the menu is empty', () async {
      final dishes = await repository.watchMenu('r1').first;

      expect(dishes, isEmpty);
    });
  });
}