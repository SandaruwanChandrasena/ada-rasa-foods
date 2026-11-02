import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/menu/data/menu_repository_impl.dart';
import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
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

  Future<void> addRestaurant(String id) {
    return firestore.collection('restaurants').doc(id).set({'name': 'Kottu'});
  }

  Future<Map<String, dynamic>?> readRaw(String restaurantId, String id) async {
    final doc = await firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('menuItems')
        .doc(id)
        .get();
    return doc.data();
  }

  const newDish = Dish(
    id: '',
    restaurantId: 'r1',
    name: 'Cheese Kottu',
    price: 1500,
    category: 'Kottu',
    description: 'With extra cheese.',
  );

  Dish copy(Dish dish, {String? id, String? name, bool? available}) {
    return Dish(
      id: id ?? dish.id,
      restaurantId: dish.restaurantId,
      name: name ?? dish.name,
      price: dish.price,
      category: dish.category,
      description: dish.description,
      imageUrl: dish.imageUrl,
      available: available ?? dish.available,
    );
  }

  group('addDish', () {
    test('saves exactly the allowed fields and gives back the id', () async {
      await addRestaurant('r1');

      final id = await repository.addDish(newDish);
      final raw = await readRaw('r1', id);

      expect(id, isNotEmpty);
      expect(raw, {
        'name': 'Cheese Kottu',
        'description': 'With extra cheese.',
        'price': 1500,
        'imageUrl': '',
        'category': 'Kottu',
        'available': true,
      });
    });

    test('the new dish shows in the live menu', () async {
      await addRestaurant('r1');

      final id = await repository.addDish(newDish);
      final dishes = await repository.watchMenu('r1').first;

      expect(dishes.single.id, id);
      expect(dishes.single.name, 'Cheese Kottu');
    });

    test('fails when the restaurant does not exist', () async {
      await expectLater(
        repository.addDish(newDish),
        throwsA(const DataFailure('This restaurant was not found.')),
      );
    });
  });

  group('updateDish', () {
    test('saves the changes', () async {
      await addRestaurant('r1');
      final id = await repository.addDish(newDish);

      await repository.updateDish(copy(newDish, id: id, name: 'Egg Kottu'));
      final raw = await readRaw('r1', id);

      expect(raw!['name'], 'Egg Kottu');
      expect(raw['price'], 1500);
    });

    test('fails when the dish was deleted', () async {
      await expectLater(
        repository.updateDish(copy(newDish, id: 'missing')),
        throwsA(const DataFailure('This dish was not found.')),
      );
      expect(await readRaw('r1', 'missing'), isNull);
    });
  });

  group('deleteDish', () {
    test('removes the dish', () async {
      await addRestaurant('r1');
      final id = await repository.addDish(newDish);

      await repository.deleteDish(copy(newDish, id: id));

      expect(await readRaw('r1', id), isNull);
    });

    test('fails when the dish is already gone', () async {
      await expectLater(
        repository.deleteDish(copy(newDish, id: 'missing')),
        throwsA(const DataFailure('This dish was not found.')),
      );
    });
  });

  group('setAvailable', () {
    test('changes only available', () async {
      await addRestaurant('r1');
      final id = await repository.addDish(newDish);

      await repository.setAvailable(copy(newDish, id: id), available: false);
      final raw = await readRaw('r1', id);

      expect(raw!['available'], isFalse);
      expect(raw['name'], 'Cheese Kottu');
      expect(raw.keys, hasLength(6));
    });

    test('fails when the dish is gone', () async {
      await expectLater(
        repository.setAvailable(copy(newDish, id: 'missing'), available: true),
        throwsA(const DataFailure('This dish was not found.')),
      );
    });
  });
}