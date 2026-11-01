import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/orders/data/order_model.dart';
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
  String restaurantId = 'r1',
  PaymentMethod method = PaymentMethod.cash,
  String phone = '0712345678',
}) {
  final isCard = method == PaymentMethod.card;
  return FoodOrder(
    customerId: customerId,
    customerName: 'Nimal',
    customerPhone: phone,
    restaurantId: restaurantId,
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
      expect(raw['customerPhone'], '0712345678');
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

    test('an order with no phone leaves the phone field out', () async {
      final id = await repository.placeOrder(newOrder(phone: ''));
      final raw = await readRaw(id);

      expect(raw.containsKey('customerPhone'), isFalse);
      expect(raw['customerName'], 'Nimal');
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
      expect(order.customerPhone, '0712345678');
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
      expect(order.customerPhone, '');
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

  Future<void> addRestaurantOrder(
    String id, {
    String restaurantId = 'r1',
    String status = 'placed',
    DateTime? placedAt,
  }) {
    return firestore.collection('orders').doc(id).set({
      'customerId': 'u1',
      'restaurantId': restaurantId,
      'status': status,
      if (placedAt != null) 'placedAt': Timestamp.fromDate(placedAt),
    });
  }

  group('watchRestaurantOpenOrders', () {
    test('shows only open orders of my restaurant, oldest first', () async {
      await addRestaurantOrder(
        'late',
        status: 'ready',
        placedAt: DateTime(2026, 11, 1, 12),
      );
      await addRestaurantOrder(
        'early',
        placedAt: DateTime(2026, 11, 1, 10),
      );
      await addRestaurantOrder(
        'middle',
        status: 'preparing',
        placedAt: DateTime(2026, 11, 1, 11),
      );
      await addRestaurantOrder(
        'accepted',
        status: 'accepted',
        placedAt: DateTime(2026, 11, 1, 11, 30),
      );
      await addRestaurantOrder(
        'done',
        status: 'completed',
        placedAt: DateTime(2026, 11, 1, 9),
      );
      await addRestaurantOrder(
        'other',
        restaurantId: 'r2',
        placedAt: DateTime(2026, 11, 1, 9),
      );

      final orders = await repository.watchRestaurantOpenOrders('r1').first;

      expect(orders.map((o) => o.id), [
        'early',
        'middle',
        'accepted',
        'late',
      ]);
    });

    test('an order with no time yet goes last', () async {
      await addRestaurantOrder('noTime');
      await addRestaurantOrder(
        'withTime',
        placedAt: DateTime(2026, 11, 1, 10),
      );

      final orders = await repository.watchRestaurantOpenOrders('r1').first;

      expect(orders.map((o) => o.id), ['withTime', 'noTime']);
    });

    test('a completed order leaves the open list live', () async {
      await addRestaurantOrder(
        'o1',
        status: 'ready',
        placedAt: DateTime(2026, 11, 1, 10),
      );
      final results = <List<FoodOrder>>[];
      final subscription =
          repository.watchRestaurantOpenOrders('r1').listen(results.add);
      await settle();

      await firestore
          .collection('orders')
          .doc('o1')
          .update({'status': 'completed'});
      await settle();

      expect(results.first.map((o) => o.id), ['o1']);
      expect(results.last, isEmpty);
      await subscription.cancel();
    });
  });

  group('watchRestaurantDoneOrders', () {
    test('shows only ended orders of my restaurant, newest first', () async {
      await addRestaurantOrder(
        'completed',
        status: 'completed',
        placedAt: DateTime(2026, 11, 1, 10),
      );
      await addRestaurantOrder(
        'rejected',
        status: 'rejected',
        placedAt: DateTime(2026, 11, 1, 12),
      );
      await addRestaurantOrder(
        'cancelled',
        status: 'cancelled',
        placedAt: DateTime(2026, 11, 1, 11),
      );
      await addRestaurantOrder(
        'open',
        placedAt: DateTime(2026, 11, 1, 13),
      );
      await addRestaurantOrder(
        'other',
        restaurantId: 'r2',
        status: 'completed',
        placedAt: DateTime(2026, 11, 1, 14),
      );

      final orders = await repository.watchRestaurantDoneOrders('r1').first;

      expect(orders.map((o) => o.id), ['rejected', 'cancelled', 'completed']);
    });

    test('shows at most the newest 50', () async {
      for (var i = 0; i < 55; i++) {
        await addRestaurantOrder(
          'o$i',
          status: 'completed',
          placedAt: DateTime(2026, 11, 1).add(Duration(minutes: i)),
        );
      }

      final orders = await repository.watchRestaurantDoneOrders('r1').first;

      expect(orders, hasLength(OrderRepositoryImpl.maxDoneOrders));
      expect(orders.first.id, 'o54');
      expect(orders.last.id, 'o5');
    });
  });

  group('moveOrder', () {
    Future<FoodOrder> placeAndRead(PaymentMethod method) async {
      final id = await repository.placeOrder(newOrder(method: method));
      return (await repository.watchOrder(id).first)!;
    }

    Future<void> setStatus(String id, String status) {
      return firestore
          .collection('orders')
          .doc(id)
          .update({'status': status});
    }

    test('accept keeps the payment and sets a new time', () async {
      final order = await placeAndRead(PaymentMethod.cash);

      await repository.moveOrder(order, OrderStatus.accepted);
      final raw = await readRaw(order.id);

      expect(raw['status'], 'accepted');
      expect(raw['paymentStatus'], 'pending');
      expect(raw['updatedAt'], isA<Timestamp>());
    });

    test('rejecting a paid card order makes it refunded', () async {
      final order = await placeAndRead(PaymentMethod.card);

      await repository.moveOrder(order, OrderStatus.rejected);
      final raw = await readRaw(order.id);

      expect(raw['status'], 'rejected');
      expect(raw['paymentStatus'], 'refunded');
    });

    test('rejecting a cash order keeps it pending', () async {
      final order = await placeAndRead(PaymentMethod.cash);

      await repository.moveOrder(order, OrderStatus.rejected);
      final raw = await readRaw(order.id);

      expect(raw['status'], 'rejected');
      expect(raw['paymentStatus'], 'pending');
    });

    test('a cash order goes all the way and ends paid', () async {
      var order = await placeAndRead(PaymentMethod.cash);

      for (final next in [
        OrderStatus.accepted,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.completed,
      ]) {
        await repository.moveOrder(order, next);
        // Read with get(). The fake's live stream can lag after a
        // transaction.
        order = OrderModel.fromMap(order.id, await readRaw(order.id));
        expect(order.status, next);
      }

      expect(order.paymentStatus, PaymentStatus.paid);
    });

    test('a completed card order stays paid', () async {
      final order = await placeAndRead(PaymentMethod.card);
      await setStatus(order.id, 'ready');
      final ready = (await repository.watchOrder(order.id).first)!;

      await repository.moveOrder(ready, OrderStatus.completed);
      final raw = await readRaw(order.id);

      expect(raw['status'], 'completed');
      expect(raw['paymentStatus'], 'paid');
    });

    test('fails if the customer cancelled a moment ago', () async {
      // The restaurant phone still has the old "placed" copy.
      final order = await placeAndRead(PaymentMethod.cash);
      await setStatus(order.id, 'cancelled');

      await expectLater(
        repository.moveOrder(order, OrderStatus.accepted),
        throwsA(const DataFailure('The customer cancelled this order.')),
      );
      final raw = await readRaw(order.id);
      expect(raw['status'], 'cancelled');
    });

    test('fails when a step is skipped', () async {
      final order = await placeAndRead(PaymentMethod.cash);

      await expectLater(
        repository.moveOrder(order, OrderStatus.ready),
        throwsA(
          const DataFailure(
            'This order is placed now. Please check the list.',
          ),
        ),
      );
      final raw = await readRaw(order.id);
      expect(raw['status'], 'placed');
    });

    test('fails when the order does not exist', () async {
      final order = await placeAndRead(PaymentMethod.cash);
      await firestore.collection('orders').doc(order.id).delete();

      await expectLater(
        repository.moveOrder(order, OrderStatus.accepted),
        throwsA(const DataFailure('This order was not found.')),
      );
    });
  });
}