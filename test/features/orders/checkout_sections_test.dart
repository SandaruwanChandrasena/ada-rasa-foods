import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/section_card.dart';
import 'package:ada_rasa_foods/features/cart/domain/cart_item.dart';
import 'package:ada_rasa_foods/features/orders/presentation/checkout_sections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const kottu = CartItem(
  dishId: 'd1',
  name: 'Chicken Kottu',
  price: 1250,
  imageUrl: 'https://example.com/kottu.jpg',
  quantity: 2,
);
const tea = CartItem(dishId: 'd2', name: 'Plain Tea', price: 150);
const longDish = CartItem(
  dishId: 'd3',
  name: 'Extra Large Seafood Cheese Kottu With Double Egg And Gravy',
  price: 3400,
);

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

  group('CheckoutPickupCard', () {
    testWidgets('shows the title and the restaurant name', (tester) async {
      await show(
        tester,
        const CheckoutPickupCard(restaurantName: 'Kottu Corner'),
      );

      expect(find.text('Pickup from'), findsOneWidget);
      expect(find.text('Kottu Corner'), findsOneWidget);
      expect(find.text('You collect it yourself'), findsOneWidget);
      expect(find.byType(SectionIcon), findsOneWidget);
    });

    testWidgets('a long name shrinks with no overflow', (tester) async {
      await show(
        tester,
        const CheckoutPickupCard(
          restaurantName: 'The Very Long Name Kottu And Rice Corner Colombo',
        ),
        width: 960,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('CheckoutOrderCard', () {
    testWidgets('shows each dish with its amount and line total',
        (tester) async {
      await show(
        tester,
        const CheckoutOrderCard(items: [kottu, tea], total: 2650),
      );

      expect(find.text('Your order'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('Chicken Kottu'), findsOneWidget);
      expect(find.text('Rs. 2,500'), findsOneWidget);
      expect(find.text('Plain Tea'), findsOneWidget);
      expect(find.text('Rs. 150'), findsOneWidget);
    });

    testWidgets('shows the total in orange', (tester) async {
      await show(
        tester,
        const CheckoutOrderCard(items: [kottu, tea], total: 2650),
      );

      expect(find.text('Total'), findsOneWidget);
      final total = tester.widget<Text>(find.text('Rs. 2,650'));
      expect(total.style?.color, AppTheme.brandOrange);
    });

    testWidgets('has no dish photos', (tester) async {
      await show(
        tester,
        const CheckoutOrderCard(items: [kottu], total: 2500),
      );

      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a long dish name shrinks and the price still shows',
        (tester) async {
      await show(
        tester,
        const CheckoutOrderCard(items: [longDish], total: 3400),
        width: 960,
      );

      expect(tester.takeException(), isNull);
      // Once in the row and once as the total.
      expect(find.text('Rs. 3,400'), findsNWidgets(2));
    });
  });

  testWidgets('the problem banner shows its message', (tester) async {
    await show(
      tester,
      const CheckoutProblemBanner(message: 'Kottu Corner is closed now.'),
    );

    expect(find.text('Kottu Corner is closed now.'), findsOneWidget);
    expect(find.byIcon(Icons.info_rounded), findsOneWidget);
  });

  group('PlaceOrderButton', () {
    testWidgets('reads "Place order · Rs. X" and can be tapped',
        (tester) async {
      var taps = 0;
      await show(
        tester,
        PlaceOrderButton(total: 2650, onPressed: () => taps++),
      );

      expect(find.text('Place order'), findsOneWidget);
      expect(find.text(' · Rs. 2,650'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      expect(taps, 1);
    });

    testWidgets('no onPressed makes it grey', (tester) async {
      await show(
        tester,
        const PlaceOrderButton(total: 2650, onPressed: null),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('while placing, a spinner shows instead of the words',
        (tester) async {
      await show(
        tester,
        PlaceOrderButton(total: 2650, placing: true, onPressed: () {}),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Place order'), findsNothing);
    });

    testWidgets('on a small phone the total still shows in full',
        (tester) async {
      await show(
        tester,
        SizedBox(
          width: double.infinity,
          child: PlaceOrderButton(total: 12500, onPressed: () {}),
        ),
        width: 960,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(' · Rs. 12,500'), findsOneWidget);
    });
  });
}