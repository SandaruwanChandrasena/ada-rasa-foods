import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/food_image.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_item.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:ada_rasa_foods/features/orders/presentation/board/restaurant_order_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const kottu = OrderItem(
  dishId: 'd1',
  name: 'Chicken Kottu',
  price: 1200,
  quantity: 2,
  imageUrl: 'https://example.com/kottu.jpg',
);

const roti = OrderItem(dishId: 'd2', name: 'Egg Roti', price: 150, quantity: 1);

FoodOrder order({
  OrderStatus status = OrderStatus.placed,
  bool card = false,
  String phone = '0712345678',
  List<OrderItem> items = const [kottu, roti],
  DateTime? placedAt,
}) {
  return FoodOrder(
    id: 'abcdef123',
    customerId: 'u1',
    customerName: 'Nimal',
    customerPhone: phone,
    restaurantId: 'r1',
    restaurantName: 'Kottu Corner',
    restaurantAddress: 'Colombo',
    items: items,
    total: items.fold<int>(0, (sum, item) => sum + item.price * item.quantity),
    paymentMethod: card ? PaymentMethod.card : PaymentMethod.cash,
    paymentStatus: card ? PaymentStatus.paid : PaymentStatus.pending,
    cardBrand: card ? 'visa' : '',
    cardLast4: card ? '4242' : '',
    status: status,
    placedAt: placedAt,
  );
}

void main() {
  late List<OrderStatus> moves;
  late List<String> calls;

  setUp(() {
    moves = [];
    calls = [];
  });

  Future<void> show(
    WidgetTester tester,
    FoodOrder order, {
    bool busy = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: RestaurantOrderCard(
              order: order,
              busy: busy,
              onMove: moves.add,
              onCall: calls.add,
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Finder callButton() => find.byKey(const Key('call-button'));

  Finder button(String text) => find.ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate(
          (widget) => widget is FilledButton || widget is TextButton,
        ),
      );

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('top part', () {
    testWidgets('shows the number, Just now and the status pill',
        (tester) async {
      await show(tester, order());

      expect(find.text('#ABCDEF'), findsOneWidget);
      expect(find.text('Just now'), findsOneWidget);
      expect(find.text('Placed'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag_rounded), findsOneWidget);
    });

    testWidgets('an older order shows minutes ago', (tester) async {
      final fiveMinutesAgo =
          DateTime.now().subtract(const Duration(minutes: 5));

      await show(tester, order(placedAt: fiveMinutesAgo));

      expect(find.text('5 min ago'), findsOneWidget);
    });

    testWidgets('the card is white with a thin border and radius 16',
        (tester) async {
      await show(tester, order());

      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(RestaurantOrderCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, BorderRadius.circular(16));
      expect(decoration.border, Border.all(color: AppTheme.border));
    });
  });

  group('customer', () {
    testWidgets('shows the name and the phone in groups', (tester) async {
      await show(tester, order());

      expect(find.text('Nimal'), findsOneWidget);
      expect(find.text('071 234 5678'), findsOneWidget);
    });

    testWidgets('the round orange call button calls the number',
        (tester) async {
      await show(tester, order());

      final circle = tester.widget<Material>(callButton());
      expect(circle.color, AppTheme.brandOrange);
      expect(circle.shape, const CircleBorder());

      await tester.tap(callButton());
      await tester.pumpAndSettle();

      expect(calls, ['0712345678']);
    });

    testWidgets('no phone: says No phone and has no call button',
        (tester) async {
      await show(tester, order(phone: ''));

      expect(find.text('No phone'), findsOneWidget);
      expect(callButton(), findsNothing);
    });
  });

  group('items', () {
    testWidgets('each item has a photo, amount and line price',
        (tester) async {
      await show(tester, order());

      expect(find.byType(FoodImage), findsNWidgets(2));
      expect(find.text('Chicken Kottu'), findsOneWidget);
      expect(find.text('× 2'), findsOneWidget);
      expect(find.text('Rs. 2,400'), findsOneWidget);
      expect(find.text('Egg Roti'), findsOneWidget);
      expect(find.text('× 1'), findsOneWidget);
      expect(find.text('Rs. 150'), findsOneWidget);
    });

    testWidgets('an item with no photo shows the food icon',
        (tester) async {
      await show(tester, order(items: const [roti]));

      expect(find.byIcon(Icons.fastfood_rounded), findsOneWidget);
    });

    testWidgets('the total is orange, with the payment text',
        (tester) async {
      await show(tester, order());

      final total = tester.widget<Text>(find.text('Rs. 2,550'));
      expect(total.style?.color, AppTheme.brandOrange);
      expect(find.text('Cash, pay at pickup'), findsOneWidget);
    });

    testWidgets('a very long dish name does not overflow', (tester) async {
      const longName = OrderItem(
        dishId: 'd3',
        name: 'Special Cheese Chicken Kottu With Extra Egg And Gravy',
        price: 2500,
        quantity: 12,
      );

      await show(tester, order(items: const [longName]));

      expect(tester.takeException(), isNull);
      expect(find.text('× 12'), findsOneWidget);
      expect(find.text('Rs. 30,000'), findsNWidgets(2));
    });
  });

  group('buttons', () {
    testWidgets('a new order has soft red Reject and orange Accept',
        (tester) async {
      await show(tester, order());

      final reject = tester.widget<TextButton>(button('Reject'));
      final style = reject.style!;
      expect(style.backgroundColor?.resolve({}), AppTheme.dangerBg);
      expect(style.foregroundColor?.resolve({}), AppTheme.dangerRed);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(button('Accept'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('Accept moves the order to accepted', (tester) async {
      await show(tester, order());

      await tapAndSettle(tester, button('Accept'));

      expect(moves, [OrderStatus.accepted]);
    });

    testWidgets('Reject asks first, and Keep changes nothing',
        (tester) async {
      await show(tester, order());

      await tapAndSettle(tester, button('Reject'));
      expect(find.text('Reject order #ABCDEF?'), findsOneWidget);

      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();

      expect(moves, isEmpty);
    });

    testWidgets('Reject in the question rejects the order', (tester) async {
      await show(tester, order());

      await tapAndSettle(tester, button('Reject'));
      await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
      await tester.pumpAndSettle();

      expect(moves, [OrderStatus.rejected]);
    });

    testWidgets('a paid card order says it will be refunded',
        (tester) async {
      await show(tester, order(card: true));

      await tapAndSettle(tester, button('Reject'));

      expect(find.textContaining('will be refunded'), findsOneWidget);
    });

    testWidgets('an accepted order shows Start preparing with a pot',
        (tester) async {
      await show(tester, order(status: OrderStatus.accepted));

      expect(find.byIcon(Icons.soup_kitchen_rounded), findsOneWidget);
      await tapAndSettle(tester, button('Start preparing'));

      expect(moves, [OrderStatus.preparing]);
    });

    testWidgets('a preparing order shows Mark ready with a bell',
        (tester) async {
      await show(tester, order(status: OrderStatus.preparing));

      expect(
        find.byIcon(Icons.notifications_active_rounded),
        findsOneWidget,
      );
      await tapAndSettle(tester, button('Mark ready'));

      expect(moves, [OrderStatus.ready]);
    });

    testWidgets('while saving: a spinner and no buttons', (tester) async {
      await show(tester, order(), busy: true, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });
  });

  group('ready and done', () {
    testWidgets('a ready cash order shows the yellow Collect note',
        (tester) async {
      await show(tester, order(status: OrderStatus.ready));

      final note = tester.widget<Text>(find.text('Collect Rs. 2,550'));
      expect(note.style?.color, RestaurantOrderCard.noteText);
      expect(find.byIcon(Icons.payments_rounded), findsOneWidget);
    });

    testWidgets('Completed on cash asks, and Not yet changes nothing',
        (tester) async {
      await show(tester, order(status: OrderStatus.ready));

      await tapAndSettle(tester, button('Completed'));
      expect(find.text('Did you collect Rs. 2,550?'), findsOneWidget);

      await tester.tap(find.text('Not yet'));
      await tester.pumpAndSettle();

      expect(moves, isEmpty);
    });

    testWidgets('Completed in the question completes the order',
        (tester) async {
      await show(tester, order(status: OrderStatus.ready));

      await tapAndSettle(tester, button('Completed'));
      await tester.tap(find.widgetWithText(FilledButton, 'Completed').last);
      await tester.pumpAndSettle();

      expect(moves, [OrderStatus.completed]);
    });

    testWidgets('a ready card order: no note, completes at once',
        (tester) async {
      await show(tester, order(status: OrderStatus.ready, card: true));

      expect(find.textContaining('Collect'), findsNothing);
      await tapAndSettle(tester, button('Completed'));

      expect(find.textContaining('Did you collect'), findsNothing);
      expect(moves, [OrderStatus.completed]);
    });

    testWidgets('a done order has no buttons and no note', (tester) async {
      await show(tester, order(status: OrderStatus.completed));

      expect(find.text('Completed'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
    });
  });
}