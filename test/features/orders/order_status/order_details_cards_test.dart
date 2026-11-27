import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/section_card.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_item.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:ada_rasa_foods/features/orders/presentation/order_status/order_details_cards.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const kottu = OrderItem(
  dishId: 'd1',
  name: 'Chicken Kottu',
  price: 1250,
  quantity: 2,
  imageUrl: 'https://example.com/kottu.jpg',
);
const tea = OrderItem(
  dishId: 'd2',
  name: 'Plain Tea',
  price: 150,
  quantity: 1,
);

FoodOrder orderWith({
  OrderStatus status = OrderStatus.placed,
  PaymentMethod method = PaymentMethod.cash,
  PaymentStatus payment = PaymentStatus.pending,
  String cardBrand = '',
  String cardLast4 = '',
  String restaurantName = 'Kottu Corner',
  List<OrderItem> items = const [kottu, tea],
  DateTime? placedAt,
}) {
  return FoodOrder(
    customerId: 'u1',
    customerName: 'Nimal',
    restaurantId: 'r1',
    restaurantName: restaurantName,
    restaurantAddress: '12 Galle Road, Colombo 03',
    items: items,
    total: 2650,
    paymentMethod: method,
    paymentStatus: payment,
    status: status,
    cardBrand: cardBrand,
    cardLast4: cardLast4,
    placedAt: placedAt,
  );
}

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
  }

  group('orderDateText', () {
    testWidgets('shows the day, month and time', (tester) async {
      late String text;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              text = orderDateText(context, DateTime(2026, 11, 25, 14, 28));
              return const SizedBox();
            },
          ),
        ),
      );

      expect(text, '25 Nov, 2:28 PM');
    });

    testWidgets('no time yet shows "Just now"', (tester) async {
      late String text;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              text = orderDateText(context, null);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(text, 'Just now');
    });
  });

  group('OrderPickupFromCard', () {
    testWidgets('shows the restaurant and when it was placed',
        (tester) async {
      await show(
        tester,
        OrderPickupFromCard(
          order: orderWith(placedAt: DateTime(2026, 11, 25, 14, 28)),
        ),
      );

      expect(find.text('Pickup from'), findsOneWidget);
      expect(find.text('Kottu Corner'), findsOneWidget);
      expect(find.text('Placed 25 Nov, 2:28 PM'), findsOneWidget);
      expect(find.byType(SectionIcon), findsOneWidget);
    });

    testWidgets('a long name fits with no overflow', (tester) async {
      await show(
        tester,
        OrderPickupFromCard(
          order: orderWith(
            restaurantName: 'The Very Long Name Kottu And Rice Corner Colombo',
          ),
        ),
        width: 960,
      );

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Pick up at shows the name and address with an orange border',
      (tester) async {
    await show(
      tester,
      OrderPickupAtCard(order: orderWith(status: OrderStatus.ready)),
    );

    expect(find.text('Pick up at'), findsOneWidget);
    expect(find.text('Kottu Corner'), findsOneWidget);
    expect(find.text('12 Galle Road, Colombo 03'), findsOneWidget);

    final box = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Pick up at'),
            matching: find.byType(Container),
          )
          .first,
    );
    final border = (box.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, AppTheme.brandOrange);
  });

  group('OrderItemsCard', () {
    testWidgets('shows each dish, its amount and the total', (tester) async {
      await show(tester, OrderItemsCard(order: orderWith()));

      expect(find.text('Your order'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget);
      expect(find.text('Chicken Kottu'), findsOneWidget);
      expect(find.text('Rs. 2,500'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('Rs. 150'), findsOneWidget);
      final total = tester.widget<Text>(find.text('Rs. 2,650'));
      expect(total.style?.color, AppTheme.brandOrange);
    });

    testWidgets('has no dish photos', (tester) async {
      await show(tester, OrderItemsCard(order: orderWith()));

      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a long dish name fits with no overflow', (tester) async {
      await show(
        tester,
        OrderItemsCard(
          order: orderWith(
            items: const [
              OrderItem(
                dishId: 'd9',
                name: 'Extra Large Seafood Cheese Kottu With Double Egg',
                price: 2650,
                quantity: 1,
              ),
            ],
          ),
        ),
        width: 960,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('OrderPaymentCard', () {
    testWidgets('a cash order to pay shows the amount', (tester) async {
      await show(tester, OrderPaymentCard(order: orderWith()));

      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Pay at pickup: Rs. 2,650'), findsOneWidget);
    });

    testWidgets('a paid cash order says so', (tester) async {
      await show(
        tester,
        OrderPaymentCard(
          order: orderWith(
            status: OrderStatus.completed,
            payment: PaymentStatus.paid,
          ),
        ),
      );

      expect(find.text('Paid in cash'), findsOneWidget);
    });

    testWidgets('a stopped cash order needs no payment', (tester) async {
      await show(
        tester,
        OrderPaymentCard(order: orderWith(status: OrderStatus.rejected)),
      );

      expect(find.text('No payment needed'), findsOneWidget);
    });

    testWidgets('a card order shows the card', (tester) async {
      await show(
        tester,
        OrderPaymentCard(
          order: orderWith(
            method: PaymentMethod.card,
            payment: PaymentStatus.paid,
            cardBrand: 'mastercard',
            cardLast4: '4444',
          ),
        ),
      );

      expect(find.text('Paid by Mastercard ending 4444'), findsOneWidget);
    });

    testWidgets('a refund is green', (tester) async {
      await show(
        tester,
        OrderPaymentCard(
          order: orderWith(
            status: OrderStatus.cancelled,
            method: PaymentMethod.card,
            payment: PaymentStatus.refunded,
            cardBrand: 'visa',
            cardLast4: '4242',
          ),
        ),
      );

      final text = tester.widget<Text>(
        find.text('Refunded (demo) to Visa ending 4242'),
      );
      expect(text.style?.color, AppTheme.successGreen);
    });
  });

  group('OrderCancelButton', () {
    late int cancels;

    setUp(() => cancels = 0);

    Future<void> showButton(
      WidgetTester tester, {
      bool isCancelling = false,
    }) async {
      await show(
        tester,
        OrderCancelButton(
          isCancelling: isCancelling,
          onCancel: () => cancels++,
        ),
      );
    }

    testWidgets('is soft red', (tester) async {
      await showButton(tester);

      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Cancel order'),
          matching: find.byWidgetPredicate((w) => w is TextButton),
        ),
      );
      final style = button.style!;
      expect(style.backgroundColor?.resolve({}), AppTheme.dangerBg);
      expect(style.foregroundColor?.resolve({}), AppTheme.dangerRed);
    });

    testWidgets('asks first, and Keep order keeps it', (tester) async {
      await showButton(tester);

      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel this order?'), findsOneWidget);

      await tester.tap(find.text('Keep order'));
      await tester.pumpAndSettle();

      expect(cancels, 0);
    });

    testWidgets('confirming cancels the order', (tester) async {
      await showButton(tester);

      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel order'));
      await tester.pumpAndSettle();

      expect(cancels, 1);
    });

    testWidgets('while cancelling, a spinner shows and it cannot be tapped',
        (tester) async {
      await showButton(tester, isCancelling: true);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Cancel order'));
      await tester.pump();

      expect(find.text('Cancel this order?'), findsNothing);
    });
  });
}