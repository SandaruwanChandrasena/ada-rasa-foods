import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/orders/data/order_repository_impl.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_item.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// Gives the fake Firestore time to send its updates.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

FoodOrder newOrder({
  String customerId = 'u1',
  PaymentMethod method = PaymentMethod.cash,
}) {
  final isCard = method == PaymentMethod.card;
  return FoodOrder(
    customerId: customerId,
    customerName: 'Nimal',
    restaurantId: 'r1',
    restaurantName: 'Kottu Corner',
    restaurantAddress: '112 Galle Road, Colombo 04',
    items: const [
      OrderItem(dishId: 'd1', name: 'Chicken Kottu', price: 1200, quantity: 2),
      OrderItem(dishId: 'd2', name: 'Faluda', price: 450, quantity: 1),
    ],
    total: 2850,
    paymentMethod: method,
    paymentStatus: isCard ? PaymentStatus.paid : PaymentStatus.pending,
    cardBrand: isCard ? 'visa' : '',
    cardLast4: isCard ? '4242' : '',
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late OrderRepositoryImpl repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = OrderRepositoryImpl(firestore);
  });

  Future<Map<String, dynamic>> readRaw(String id) async {
    final doc = await firestore.collection('orders').doc(id).get();
    return doc.data()!;
  }

  group('placeOrder', () {
    test('saves every field and gives back the new id', () async {
      final id = await repository.placeOrder(newOrder());
      final raw = await readRaw(id);

      expect(id, isNotEmpty);
      expect(raw['customerId'], 'u1');
      expect(raw['restaurantName'], 'Kottu Corner');
      expect(raw['total'], 2850);
      expect(raw['status'], 'placed');
      expect(raw['fulfillment'], 'pickup');
      expect(raw['paymentMethod'], 'cash');
      expect(raw['paymentStatus'], 'pending');
      expect(raw['cardLast4'], '');
      expect(raw['placedAt'], isA<Timestamp>());
      expect(raw['updatedAt'], isA<Timestamp>());
    });

    test('saves the dishes as a list of copies', () async {
      final id = await repository.placeOrder(newOrder());
      final raw = await readRaw(id);

      expect(raw['items'], [
        {
          'dishId': 'd1',
          'name': 'Chicken Kottu',
          'price': 1200,
          'quantity': 2,
          'imageUrl': '',
        },
        {
          'dishId': 'd2',
          'name': 'Faluda',
          'price': 450,
          'quantity': 1,
          'imageUrl': '',
        },
      ]);
    });

    test('a card order saves paid, the card type, and last 4', () async {
      final id = await repository.placeOrder(
        newOrder(method: PaymentMethod.card),
      );
      final raw = await readRaw(id);

      expect(raw['paymentMethod'], 'card');
      expect(raw['paymentStatus'], 'paid');
      expect(raw['cardBrand'], 'visa');
      expect(raw['cardLast4'], '4242');
    });
  });

  group('watchOrder', () {
    test('reads the saved order back the same', () async {
      final id = await repository.placeOrder(newOrder());

      final order = await repository.watchOrder(id).first;

      expect(order, isNotNull);
      expect(order!.id, id);
      expect(order.items, newOrder().items);
      expect(order.total, 2850);
      expect(order.status, OrderStatus.placed);
      expect(order.placedAt, isNotNull);
    });

    test('gives null when the order does not exist', () async {
      final order = await repository.watchOrder('missing').first;

      expect(order, isNull);
    });

    test('sends a live update when the restaurant accepts', () async {
      final id = await repository.placeOrder(newOrder());
      final results = <FoodOrder?>[];
      final subscription = repository.watchOrder(id).listen(results.add);
      await settle();

      await firestore
          .collection('orders')
          .doc(id)
          .update({'status': 'accepted'});
      await settle();

      expect(results.first!.status, OrderStatus.placed);
      expect(results.last!.status, OrderStatus.accepted);
      await subscription.cancel();
    });

    test('missing fields get safe defaults', () async {
      await firestore.collection('orders').doc('o1').set({
        'customerId': 'u1',
      });

      final order = await repository.watchOrder('o1').first;

      expect(order!.items, isEmpty);
      expect(order.total, 0);
      expect(order.status, OrderStatus.placed);
      expect(order.paymentMethod, PaymentMethod.cash);
      expect(order.paymentStatus, PaymentStatus.pending);
      expect(order.placedAt, isNull);
    });
  });

  group('watchCustomerOrders', () {
    Future<void> addRaw(String id, String customerId, DateTime placedAt) {
      return firestore.collection('orders').doc(id).set({
        'customerId': customerId,
        'status': 'placed',
        'placedAt': Timestamp.fromDate(placedAt),
      });
    }

    test('shows only my orders, newest first', () async {
      await addRaw('old', 'u1', DateTime(2026, 10, 28));
      await addRaw('new', 'u1', DateTime(2026, 10, 30));
      await addRaw('other', 'u2', DateTime(2026, 10, 29));

      final orders = await repository.watchCustomerOrders('u1').first;

      expect(orders.map((o) => o.id), ['new', 'old']);
    });

    test('gives an empty list when I have no orders', () async {
      final orders = await repository.watchCustomerOrders('u1').first;

      expect(orders, isEmpty);
    });
  });

  group('cancelOrder', () {
    Future<FoodOrder> placeAndRead(PaymentMethod method) async {
      final id = await repository.placeOrder(newOrder(method: method));
      return (await repository.watchOrder(id).first)!;
    }

    test('a cash order becomes cancelled and stays pending', () async {
      final order = await placeAndRead(PaymentMethod.cash);

      await repository.cancelOrder(order);
      final raw = await readRaw(order.id);

      expect(raw['status'], 'cancelled');
      expect(raw['paymentStatus'], 'pending');
    });

    test('a paid card order becomes cancelled and refunded', () async {
      final order = await placeAndRead(PaymentMethod.card);

      await repository.cancelOrder(order);
      final raw = await readRaw(order.id);

      expect(raw['status'], 'cancelled');
      expect(raw['paymentStatus'], 'refunded');
    });

    test('fails if the restaurant accepted it a moment ago', () async {
      // The phone still has the old "placed" copy.
      final order = await placeAndRead(PaymentMethod.cash);
      await firestore
          .collection('orders')
          .doc(order.id)
          .update({'status': 'accepted'});

      await expectLater(
        repository.cancelOrder(order),
        throwsA(
          const DataFailure(
            'This order is accepted now. It can no longer be cancelled.',
          ),
        ),
      );
      final raw = await readRaw(order.id);
      expect(raw['status'], 'accepted');
    });

    test('fails when the order does not exist', () async {
      final order = newOrder();
      final missing = FoodOrder(
        id: 'missing',
        customerId: order.customerId,
        customerName: order.customerName,
        restaurantId: order.restaurantId,
        restaurantName: order.restaurantName,
        restaurantAddress: order.restaurantAddress,
        items: order.items,
        total: order.total,
        paymentMethod: order.paymentMethod,
        paymentStatus: order.paymentStatus,
      );

      await expectLater(
        repository.cancelOrder(missing),
        throwsA(const DataFailure('This order was not found.')),
      );
    });
  });
}