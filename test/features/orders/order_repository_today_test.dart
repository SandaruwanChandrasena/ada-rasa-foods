import 'package:ada_rasa_foods/features/orders/data/order_repository_impl.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// Gives the fake Firestore time to send its updates.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeFirebaseFirestore firestore;
  late OrderRepositoryImpl repository;

  final today = DateTime(2026, 11, 27);

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = OrderRepositoryImpl(firestore);
  });

  Future<void> addOrder(
    String id, {
    String restaurantId = 'r1',
    String status = 'completed',
    required DateTime placedAt,
  }) {
    return firestore.collection('orders').doc(id).set({
      'customerId': 'u1',
      'restaurantId': restaurantId,
      'status': status,
      'total': 1000,
      'placedAt': Timestamp.fromDate(placedAt),
    });
  }

  group('watchRestaurantEndedSince', () {
    test('shows only ended orders placed today, newest first', () async {
      await addOrder(
        'completed',
        placedAt: today.add(const Duration(hours: 9)),
      );
      await addOrder(
        'rejected',
        status: 'rejected',
        placedAt: today.add(const Duration(hours: 11)),
      );
      await addOrder(
        'cancelled',
        status: 'cancelled',
        placedAt: today.add(const Duration(hours: 10)),
      );
      await addOrder(
        'open',
        status: 'ready',
        placedAt: today.add(const Duration(hours: 12)),
      );

      final orders =
          await repository.watchRestaurantEndedSince('r1', today).first;

      expect(orders.map((o) => o.id), ['rejected', 'cancelled', 'completed']);
    });

    test('leaves out orders placed before midnight', () async {
      await addOrder(
        'yesterday',
        placedAt: today.subtract(const Duration(minutes: 1)),
      );
      await addOrder('midnight', placedAt: today);

      final orders =
          await repository.watchRestaurantEndedSince('r1', today).first;

      expect(orders.map((o) => o.id), ['midnight']);
    });

    test('leaves out other restaurants', () async {
      await addOrder(
        'other',
        restaurantId: 'r2',
        placedAt: today.add(const Duration(hours: 9)),
      );

      final orders =
          await repository.watchRestaurantEndedSince('r1', today).first;

      expect(orders, isEmpty);
    });

    test('has no 50 limit like the Done tab', () async {
      for (var i = 0; i < 60; i++) {
        await addOrder('o$i', placedAt: today.add(Duration(minutes: i)));
      }

      final orders =
          await repository.watchRestaurantEndedSince('r1', today).first;

      expect(orders, hasLength(60));
      expect(orders.first.id, 'o59');
    });

    test('an order completed now joins the list live', () async {
      await addOrder(
        'o1',
        status: 'ready',
        placedAt: today.add(const Duration(hours: 9)),
      );
      final results = <List<FoodOrder>>[];
      final subscription = repository
          .watchRestaurantEndedSince('r1', today)
          .listen(results.add);
      await settle();

      await firestore
          .collection('orders')
          .doc('o1')
          .update({'status': 'completed'});
      await settle();

      expect(results.first, isEmpty);
      expect(results.last.map((o) => o.id), ['o1']);
      await subscription.cancel();
    });
  });
}