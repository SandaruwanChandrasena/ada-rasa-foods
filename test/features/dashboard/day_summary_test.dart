import 'package:ada_rasa_foods/features/dashboard/domain/day_summary.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_item.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:flutter_test/flutter_test.dart';

FoodOrder order(
  OrderStatus status, {
  int total = 1000,
  List<OrderItem> items = const [],
}) {
  return FoodOrder(
    customerId: 'u1',
    customerName: 'Nimal',
    restaurantId: 'r1',
    restaurantName: 'Kottu Corner',
    restaurantAddress: '112 Galle Road',
    items: items,
    total: total,
    paymentMethod: PaymentMethod.cash,
    paymentStatus: PaymentStatus.pending,
    status: status,
  );
}

OrderItem item(String id, int quantity, {String imageUrl = ''}) {
  return OrderItem(
    dishId: id,
    name: 'Dish $id',
    price: 500,
    quantity: quantity,
    imageUrl: imageUrl,
  );
}

void main() {
  test('no orders gives all zeros and no top dishes', () {
    final summary = DaySummary.from(open: const [], endedToday: const []);

    expect(summary, const DaySummary());
  });

  test('sales add up completed orders only', () {
    final summary = DaySummary.from(
      open: [order(OrderStatus.ready, total: 900)],
      endedToday: [
        order(OrderStatus.completed, total: 1200),
        order(OrderStatus.completed, total: 800),
        order(OrderStatus.rejected, total: 5000),
        order(OrderStatus.cancelled, total: 3000),
      ],
    );

    expect(summary.sales, 2000);
    expect(summary.doneCount, 2);
  });

  test('rejected and cancelled count together', () {
    final summary = DaySummary.from(
      open: const [],
      endedToday: [
        order(OrderStatus.rejected),
        order(OrderStatus.cancelled),
        order(OrderStatus.completed),
      ],
    );

    expect(summary.droppedCount, 2);
  });

  test('placed orders are New, the other open orders are Active', () {
    final summary = DaySummary.from(
      open: [
        order(OrderStatus.placed),
        order(OrderStatus.placed),
        order(OrderStatus.accepted),
        order(OrderStatus.preparing),
        order(OrderStatus.ready),
      ],
      endedToday: const [],
    );

    expect(summary.newCount, 2);
    expect(summary.activeCount, 3);
  });

  test('top dishes add quantities across orders, most first', () {
    final summary = DaySummary.from(
      open: const [],
      endedToday: [
        order(OrderStatus.completed, items: [item('a', 1), item('b', 2)]),
        order(OrderStatus.completed, items: [item('a', 3)]),
      ],
    );

    expect(summary.topDishes, const [
      TopDish(dishId: 'a', name: 'Dish a', quantity: 4),
      TopDish(dishId: 'b', name: 'Dish b', quantity: 2),
    ]);
  });

  test('top dishes skip rejected, cancelled and open orders', () {
    final summary = DaySummary.from(
      open: [
        order(OrderStatus.preparing, items: [item('open', 9)]),
      ],
      endedToday: [
        order(OrderStatus.rejected, items: [item('rejected', 9)]),
        order(OrderStatus.cancelled, items: [item('cancelled', 9)]),
        order(OrderStatus.completed, items: [item('sold', 1)]),
      ],
    );

    expect(summary.topDishes.map((d) => d.dishId), ['sold']);
  });

  test('top dishes show at most 3', () {
    final summary = DaySummary.from(
      open: const [],
      endedToday: [
        order(
          OrderStatus.completed,
          items: [
            item('a', 5),
            item('b', 4),
            item('c', 3),
            item('d', 2),
          ],
        ),
      ],
    );

    expect(summary.topDishes, hasLength(DaySummary.maxTopDishes));
    expect(summary.topDishes.map((d) => d.dishId), ['a', 'b', 'c']);
  });

  test('a tie is sorted by name', () {
    final summary = DaySummary.from(
      open: const [],
      endedToday: [
        order(OrderStatus.completed, items: [item('b', 2), item('a', 2)]),
      ],
    );

    expect(summary.topDishes.map((d) => d.dishId), ['a', 'b']);
  });

  test('a dish keeps the newest name and any photo it has', () {
    final summary = DaySummary.from(
      open: const [],
      endedToday: [
        order(
          OrderStatus.completed,
          items: const [
            OrderItem(dishId: 'a', name: 'New name', price: 1, quantity: 1),
          ],
        ),
        order(
          OrderStatus.completed,
          items: const [
            OrderItem(
              dishId: 'a',
              name: 'Old name',
              price: 1,
              quantity: 1,
              imageUrl: 'https://img/a.jpg',
            ),
          ],
        ),
      ],
    );

    expect(
      summary.topDishes.single,
      const TopDish(
        dishId: 'a',
        name: 'New name',
        quantity: 2,
        imageUrl: 'https://img/a.jpg',
      ),
    );
  });
}