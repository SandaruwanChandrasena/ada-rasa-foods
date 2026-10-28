import 'package:ada_rasa_foods/features/restaurants/data/restaurant_repository_impl.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// Gives the fake Firestore time to send its updates.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeFirebaseFirestore firestore;
  late RestaurantRepositoryImpl repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = RestaurantRepositoryImpl(firestore);
  });

  Future<void> addRestaurant(
    String id, {
    required String name,
    bool isActive = true,
  }) {
    return firestore.collection('restaurants').doc(id).set({
      'name': name,
      'cuisine': 'Sri Lankan',
      'ownerId': 'owner_$id',
      'imageUrl': '',
      'address': '112 Galle Road, Colombo 04',
      'location': const GeoPoint(6.8885, 79.8567),
      'isOpen': true,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(DateTime(2026, 10, 28)),
    });
  }

  group('watchActiveRestaurants', () {
    test('shows only active restaurants', () async {
      await addRestaurant('r1', name: 'Kottu Corner');
      await addRestaurant('r2', name: 'Hidden Place', isActive: false);

      final restaurants = await repository.watchActiveRestaurants().first;

      expect(restaurants.map((r) => r.id), ['r1']);
    });

    test('sorts restaurants A to Z, ignoring capital letters', () async {
      await addRestaurant('r1', name: 'slice Street Pizza');
      await addRestaurant('r2', name: 'Amma Rice');
      await addRestaurant('r3', name: 'Golden Wok');

      final restaurants = await repository.watchActiveRestaurants().first;

      expect(
        restaurants.map((r) => r.name),
        ['Amma Rice', 'Golden Wok', 'slice Street Pizza'],
      );
    });

    test('gives an empty list when there are no restaurants', () async {
      final restaurants = await repository.watchActiveRestaurants().first;

      expect(restaurants, isEmpty);
    });

    test('sends a live update when the admin turns a restaurant off', () async {
      await addRestaurant('r1', name: 'Kottu Corner');
      final results = <List<Restaurant>>[];
      final subscription =
          repository.watchActiveRestaurants().listen(results.add);
      await settle();

      await firestore
          .collection('restaurants')
          .doc('r1')
          .update({'isActive': false});
      await settle();

      expect(results.first, hasLength(1));
      expect(results.last, isEmpty);
      await subscription.cancel();
    });
  });

  group('watchRestaurant', () {
    test('reads all fields correctly', () async {
      await addRestaurant('r1', name: 'Kottu Corner');

      final restaurant = await repository.watchRestaurant('r1').first;

      expect(restaurant, isNotNull);
      expect(restaurant!.name, 'Kottu Corner');
      expect(restaurant.cuisine, 'Sri Lankan');
      expect(restaurant.ownerId, 'owner_r1');
      expect(restaurant.latitude, 6.8885);
      expect(restaurant.longitude, 79.8567);
      expect(restaurant.isOpen, isTrue);
      expect(restaurant.isActive, isTrue);
      expect(restaurant.createdAt, DateTime(2026, 10, 28));
    });

    test('gives null when the restaurant does not exist', () async {
      final restaurant = await repository.watchRestaurant('missing').first;

      expect(restaurant, isNull);
    });

    test('missing fields get safe defaults: closed and hidden', () async {
      await firestore.collection('restaurants').doc('r1').set({
        'name': 'Half Data Cafe',
      });

      final restaurant = await repository.watchRestaurant('r1').first;

      expect(restaurant!.isOpen, isFalse);
      expect(restaurant.isActive, isFalse);
      expect(restaurant.imageUrl, '');
      expect(restaurant.latitude, 0.0);
      expect(restaurant.createdAt, isNull);
    });
  });

  group('Restaurant helpers', () {
    const openRestaurant = Restaurant(
      id: 'r1',
      name: 'Kottu Corner',
      cuisine: 'Sri Lankan',
      ownerId: 'owner_1',
      address: 'Colombo',
      latitude: 6.9,
      longitude: 79.8,
    );

    test('an open and active restaurant can take orders', () {
      expect(openRestaurant.canTakeOrders, isTrue);
    });

    test('a closed restaurant cannot take orders', () {
      const closed = Restaurant(
        id: 'r1',
        name: 'Kottu Corner',
        cuisine: 'Sri Lankan',
        ownerId: 'owner_1',
        address: 'Colombo',
        latitude: 6.9,
        longitude: 79.8,
        isOpen: false,
      );

      expect(closed.canTakeOrders, isFalse);
    });

    test('hasImage is false when imageUrl is empty', () {
      expect(openRestaurant.hasImage, isFalse);
    });
  });
}