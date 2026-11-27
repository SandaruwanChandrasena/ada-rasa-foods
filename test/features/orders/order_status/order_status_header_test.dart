import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:ada_rasa_foods/features/orders/presentation/order_status/order_status_header.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

FoodOrder orderWith(
  OrderStatus status, {
  String restaurantName = 'Kottu Corner',
}) {
  return FoodOrder(
    customerId: 'u1',
    customerName: 'Nimal',
    restaurantId: 'r1',
    restaurantName: restaurantName,
    restaurantAddress: '12 Galle Road, Colombo 03',
    items: const [],
    total: 2650,
    paymentMethod: PaymentMethod.cash,
    paymentStatus: PaymentStatus.pending,
    status: status,
  );
}

// The soft background colour of the status card.
Color cardColor(WidgetTester tester) {
  final box = tester.widget<AnimatedContainer>(
    find.byType(AnimatedContainer).first,
  );
  return (box.decoration! as BoxDecoration).color!;
}

Finder stepRow(int index) => find.byKey(ValueKey('order_step_$index'));

bool rowHasIcon(int index, IconData icon) => find
    .descendant(of: stepRow(index), matching: find.byIcon(icon))
    .evaluate()
    .isNotEmpty;

bool isDone(int index) => rowHasIcon(index, Icons.check_circle_rounded);

bool isNow(int index) =>
    rowHasIcon(index, Icons.radio_button_checked_rounded);

bool isWaiting(int index) =>
    rowHasIcon(index, Icons.radio_button_unchecked_rounded);

void main() {
  Future<void> show(
    WidgetTester tester,
    Widget child, {
    double width = 1080,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('OrderStatusCard', () {
    testWidgets('placed: orange, waiting for the restaurant', (tester) async {
      await show(tester, OrderStatusCard(order: orderWith(OrderStatus.placed)));

      expect(find.text('Placed'), findsOneWidget);
      expect(find.text('Waiting for Kottu Corner'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(cardColor(tester), AppTheme.softOrange);
    });

    testWidgets('each going step has its own short message', (tester) async {
      final messages = {
        OrderStatus.accepted: 'Kottu Corner accepted it',
        OrderStatus.preparing: 'Your food is cooking',
      };
      for (final entry in messages.entries) {
        await show(tester, OrderStatusCard(order: orderWith(entry.key)));
        expect(find.text(entry.value), findsOneWidget);
        expect(cardColor(tester), AppTheme.softOrange);
      }
    });

    testWidgets('ready for pickup is green', (tester) async {
      await show(tester, OrderStatusCard(order: orderWith(OrderStatus.ready)));

      expect(find.text('Ready for pickup'), findsOneWidget);
      expect(find.text('Please collect it'), findsOneWidget);
      expect(cardColor(tester), AppTheme.successBg);
    });

    testWidgets('completed is green', (tester) async {
      await show(
        tester,
        OrderStatusCard(order: orderWith(OrderStatus.completed)),
      );

      expect(find.text('Enjoy your meal!'), findsOneWidget);
      expect(cardColor(tester), AppTheme.successBg);
    });

    testWidgets('rejected and cancelled are soft red', (tester) async {
      await show(
        tester,
        OrderStatusCard(order: orderWith(OrderStatus.rejected)),
      );
      expect(find.text('Kottu Corner could not take it'), findsOneWidget);
      expect(cardColor(tester), AppTheme.dangerBg);

      await show(
        tester,
        OrderStatusCard(order: orderWith(OrderStatus.cancelled)),
      );
      expect(find.text('You cancelled this order'), findsOneWidget);
      expect(cardColor(tester), AppTheme.dangerBg);
    });

    testWidgets('a long restaurant name fits with no overflow',
        (tester) async {
      await show(
        tester,
        OrderStatusCard(
          order: orderWith(
            OrderStatus.placed,
            restaurantName: 'The Very Long Name Kottu And Rice Corner Colombo',
          ),
        ),
        width: 960,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('OrderStatusSteps', () {
    testWidgets('shows the 5 pickup steps in order', (tester) async {
      await show(
        tester,
        const OrderStatusSteps(current: OrderStatus.placed),
      );

      final labels = [
        'Placed',
        'Accepted',
        'Preparing',
        'Ready for pickup',
        'Completed',
      ];
      for (var i = 1; i < labels.length; i++) {
        expect(
          tester.getTopLeft(find.text(labels[i - 1])).dy,
          lessThan(tester.getTopLeft(find.text(labels[i])).dy),
        );
      }
    });

    testWidgets('preparing: 2 done, 1 now, 2 waiting', (tester) async {
      await show(
        tester,
        const OrderStatusSteps(current: OrderStatus.preparing),
      );

      expect(isDone(0), isTrue);
      expect(isDone(1), isTrue);
      expect(isNow(2), isTrue);
      expect(isWaiting(3), isTrue);
      expect(isWaiting(4), isTrue);
    });

    testWidgets('completed: all 5 done', (tester) async {
      await show(
        tester,
        const OrderStatusSteps(current: OrderStatus.completed),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(5));
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsNothing);
    });

    testWidgets('only the step now shows the time', (tester) async {
      await show(
        tester,
        OrderStatusSteps(
          current: OrderStatus.accepted,
          updatedAt: DateTime(2026, 11, 25, 14, 41),
        ),
      );

      expect(find.text('2:41 PM'), findsOneWidget);
      expect(
        find.descendant(of: stepRow(1), matching: find.text('2:41 PM')),
        findsOneWidget,
      );
    });

    testWidgets('no time while it is on its way', (tester) async {
      await show(
        tester,
        const OrderStatusSteps(current: OrderStatus.accepted),
      );

      expect(find.textContaining('PM'), findsNothing);
      expect(find.textContaining('AM'), findsNothing);
    });

    testWidgets('screen readers hear each step and its state',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await show(
        tester,
        const OrderStatusSteps(current: OrderStatus.accepted),
      );

      expect(find.bySemanticsLabel('Placed, done'), findsOneWidget);
      expect(find.bySemanticsLabel('Accepted, now'), findsOneWidget);
      expect(find.bySemanticsLabel('Preparing, waiting'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a small phone with a time has no overflow', (tester) async {
      await show(
        tester,
        OrderStatusSteps(
          current: OrderStatus.ready,
          updatedAt: DateTime(2026, 11, 25, 14, 41),
        ),
        width: 960,
      );

      expect(tester.takeException(), isNull);
    });
  });
}