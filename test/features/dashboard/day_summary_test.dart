import 'package:ada_rasa_foods/features/dashboard/domain/day_summary.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_item.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:flutter_test/flutter_test.dart';

final midnight = DateTime(2026, 11, 28);

FoodOrder order(
  OrderStatus status, {
  int total = 1000,
  List<OrderItem> items = const [],
  DateTime? placedAt,
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
    placedAt: placedAt ?? midnight.add(const Duration(hours: 10)),
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

DaySummary summarize({
  List<FoodOrder> open = const [],
  List<FoodOrder> ended = const [],
  int maxTopDishes = 3,
}) {
  return DaySummary.from(
    open: open,
    ended: ended,
    since: midnight,
    maxTopDishes: maxTopDishes,
  );
}

void main() {
  group('DaySummary.from', () {
    test('no orders gives all zeros and no top dishes', () {
      expect(summarize(), const DaySummary());
    });

    test('sales add up completed orders only', () {
      final summary = summarize(
        open: [order(OrderStatus.ready, total: 900)],
        ended: [
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
      final summary = summarize(
        ended: [
          order(OrderStatus.rejected),
          order(OrderStatus.cancelled),
          order(OrderStatus.completed),
        ],
      );

      expect(summary.droppedCount, 2);
    });

    test('placed orders are New, the other open orders are Active', () {
      final summary = summarize(
        open: [
          order(OrderStatus.placed),
          order(OrderStatus.placed),
          order(OrderStatus.accepted),
          order(OrderStatus.preparing),
          order(OrderStatus.ready),
        ],
      );

      expect(summary.newCount, 2);
      expect(summary.activeCount, 3);
    });

    test('orders placed before the period are left out', () {
      final before = midnight.subtract(const Duration(minutes: 1));
      final summary = summarize(
        ended: [
          order(OrderStatus.completed, total: 700, placedAt: before),
          order(OrderStatus.rejected, placedAt: before),
          order(OrderStatus.completed, total: 300, placedAt: midnight),
        ],
      );

      expect(summary.sales, 300);
      expect(summary.doneCount, 1);
      expect(summary.droppedCount, 0);
    });

    test('open orders count even when placed before the period', () {
      final summary = summarize(
        open: [
          order(
            OrderStatus.preparing,
            placedAt: midnight.subtract(const Duration(days: 2)),
          ),
        ],
      );

      expect(summary.activeCount, 1);
    });

    test('an ended order with no time yet counts', () {
      final noTime = FoodOrder(
        customerId: 'u1',
        customerName: 'Nimal',
        restaurantId: 'r1',
        restaurantName: 'Kottu Corner',
        restaurantAddress: '112 Galle Road',
        items: const [],
        total: 400,
        paymentMethod: PaymentMethod.cash,
        paymentStatus: PaymentStatus.paid,
        status: OrderStatus.completed,
      );

      expect(summarize(ended: [noTime]).sales, 400);
    });

    test('top dishes add quantities across orders, most first', () {
      final summary = summarize(
        ended: [
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
      final summary = summarize(
        open: [
          order(OrderStatus.preparing, items: [item('open', 9)]),
        ],
        ended: [
          order(OrderStatus.rejected, items: [item('rejected', 9)]),
          order(OrderStatus.cancelled, items: [item('cancelled', 9)]),
          order(OrderStatus.completed, items: [item('sold', 1)]),
        ],
      );

      expect(summary.topDishes.map((d) => d.dishId), ['sold']);
    });

    test('top dishes show at most the asked number', () {
      final sold = order(
        OrderStatus.completed,
        items: [
          item('a', 6),
          item('b', 5),
          item('c', 4),
          item('d', 3),
          item('e', 2),
          item('f', 1),
        ],
      );

      expect(
        summarize(ended: [sold]).topDishes.map((d) => d.dishId),
        ['a', 'b', 'c'],
      );
      expect(
        summarize(ended: [sold], maxTopDishes: 5)
            .topDishes
            .map((d) => d.dishId),
        ['a', 'b', 'c', 'd', 'e'],
      );
    });

    test('a tie is sorted by name', () {
      final summary = summarize(
        ended: [
          order(OrderStatus.completed, items: [item('b', 2), item('a', 2)]),
        ],
      );

      expect(summary.topDishes.map((d) => d.dishId), ['a', 'b']);
    });

    test('a dish keeps the newest name and any photo it has', () {
      final summary = summarize(
        ended: [
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
  });

  group('salesByDay', () {
    final now = DateTime(2026, 11, 28, 0, 17);

    FoodOrder soldOn(DateTime day, int total) {
      return order(OrderStatus.completed, total: total, placedAt: day);
    }

    test('gives 7 zeros when nothing was sold', () {
      expect(salesByDay(const [], now), [0, 0, 0, 0, 0, 0, 0]);
    });

    test('puts each sale on its day, today last', () {
      final totals = salesByDay([
        soldOn(DateTime(2026, 11, 28, 0, 5), 100),
        soldOn(DateTime(2026, 11, 27, 23, 50), 200),
        soldOn(DateTime(2026, 11, 27, 9), 50),
        soldOn(DateTime(2026, 11, 22, 12), 400),
      ], now);

      expect(totals, [400, 0, 0, 0, 0, 250, 100]);
    });

    test('leaves out days older than 7 days', () {
      final totals = salesByDay([
        soldOn(DateTime(2026, 11, 21, 23, 59), 999),
      ], now);

      expect(totals, [0, 0, 0, 0, 0, 0, 0]);
    });

    test('counts completed orders only', () {
      final totals = salesByDay([
        order(OrderStatus.rejected, total: 500, placedAt: now),
        order(OrderStatus.cancelled, total: 500, placedAt: now),
      ], now);

      expect(totals.last, 0);
    });

    test('works across the start of a month', () {
      final totals = salesByDay(
        [soldOn(DateTime(2026, 11, 30, 18), 300)],
        DateTime(2026, 12, 2, 8),
      );

      expect(totals, [0, 0, 0, 0, 300, 0, 0]);
    });
  });
}