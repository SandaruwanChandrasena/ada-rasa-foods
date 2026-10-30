import 'package:ada_rasa_foods/features/cart/domain/cart.dart';
import 'package:ada_rasa_foods/features/cart/domain/cart_item.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_item.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cart = Cart(
    restaurantId: 'r1',
    restaurantName: 'Kottu Corner',
    items: const [
      CartItem(dishId: 'd1', name: 'Chicken Kottu', price: 1200, quantity: 2),
      CartItem(dishId: 'd2', name: 'Faluda', price: 450),
    ],
    updatedAt: DateTime(2026, 10, 30, 10),
  );

  FoodOrder fromCart(
    PaymentMethod method, {
    String cardBrand = 'visa',
    String cardLast4 = '4242',
  }) {
    return FoodOrder.fromCart(
      cart: cart,
      customerId: 'u1',
      customerName: 'Nimal',
      restaurantAddress: '112 Galle Road, Colombo 04',
      paymentMethod: method,
      cardBrand: cardBrand,
      cardLast4: cardLast4,
    );
  }

  group('OrderStatus', () {
    test('ready shows "Ready for pickup" for a pickup order', () {
      expect(
        OrderStatus.ready.labelFor(Fulfillment.pickup),
        'Ready for pickup',
      );
    });

    test('ready shows "Ready" for a delivery order', () {
      expect(OrderStatus.ready.labelFor(Fulfillment.delivery), 'Ready');
    });

    test('only completed, delivered, rejected, cancelled are end states', () {
      final ends = OrderStatus.values.where((s) => s.isEnd).toList();

      expect(ends, [
        OrderStatus.completed,
        OrderStatus.delivered,
        OrderStatus.rejected,
        OrderStatus.cancelled,
      ]);
    });

    test('pickup steps are in the right order', () {
      expect(OrderStatus.pickupSteps, [
        OrderStatus.placed,
        OrderStatus.accepted,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.completed,
      ]);
    });
  });

  group('FoodOrder.fromCart', () {
    test('copies the restaurant, dishes, and total from the cart', () {
      final order = fromCart(PaymentMethod.cash);

      expect(order.restaurantId, 'r1');
      expect(order.restaurantName, 'Kottu Corner');
      expect(order.restaurantAddress, '112 Galle Road, Colombo 04');
      expect(order.items, const [
        OrderItem(
          dishId: 'd1',
          name: 'Chicken Kottu',
          price: 1200,
          quantity: 2,
        ),
        OrderItem(dishId: 'd2', name: 'Faluda', price: 450, quantity: 1),
      ]);
      expect(order.total, 2850);
      expect(order.itemCount, 3);
    });

    test('a new order is a placed pickup order with no id yet', () {
      final order = fromCart(PaymentMethod.cash);

      expect(order.status, OrderStatus.placed);
      expect(order.fulfillment, Fulfillment.pickup);
      expect(order.id, '');
    });

    test('a cash order is pending and keeps no card details', () {
      final order = fromCart(PaymentMethod.cash);

      expect(order.paymentStatus, PaymentStatus.pending);
      expect(order.cardBrand, '');
      expect(order.cardLast4, '');
    });

    test('a card order is paid and keeps the card type and last 4', () {
      final order = fromCart(PaymentMethod.card);

      expect(order.paymentStatus, PaymentStatus.paid);
      expect(order.cardBrand, 'visa');
      expect(order.cardLast4, '4242');
    });
  });

  group('FoodOrder helpers', () {
    const order = FoodOrder(
      id: 'a7k3q2XYZabc',
      customerId: 'u1',
      customerName: 'Nimal',
      restaurantId: 'r1',
      restaurantName: 'Kottu Corner',
      restaurantAddress: 'Colombo',
      items: [],
      total: 0,
      paymentMethod: PaymentMethod.card,
      paymentStatus: PaymentStatus.paid,
    );

    FoodOrder withStatus(OrderStatus status, {bool card = true}) {
      return FoodOrder(
        id: order.id,
        customerId: 'u1',
        customerName: 'Nimal',
        restaurantId: 'r1',
        restaurantName: 'Kottu Corner',
        restaurantAddress: 'Colombo',
        items: const [],
        total: 0,
        paymentMethod: card ? PaymentMethod.card : PaymentMethod.cash,
        paymentStatus: card ? PaymentStatus.paid : PaymentStatus.pending,
        status: status,
      );
    }

    test('shortNumber is the first 6 letters in capitals', () {
      expect(order.shortNumber, 'A7K3Q2');
    });

    test('shortNumber is empty when there is no id', () {
      expect(fromCart(PaymentMethod.cash).shortNumber, '');
    });

    test('the customer can cancel only a placed order', () {
      expect(withStatus(OrderStatus.placed).canCancel, isTrue);
      expect(withStatus(OrderStatus.accepted).canCancel, isFalse);
      expect(withStatus(OrderStatus.cancelled).canCancel, isFalse);
    });

    test('cancelling a paid card order makes it refunded', () {
      expect(order.paymentStatusAfterCancel, PaymentStatus.refunded);
    });

    test('cancelling a cash order keeps it pending', () {
      final cash = withStatus(OrderStatus.placed, card: false);

      expect(cash.paymentStatusAfterCancel, PaymentStatus.pending);
    });

    test('statusLabel uses the pickup label for ready', () {
      expect(withStatus(OrderStatus.ready).statusLabel, 'Ready for pickup');
    });
  });
}