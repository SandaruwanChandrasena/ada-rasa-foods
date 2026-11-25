import 'package:ada_rasa_foods/core/router/app_router.dart';
import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/round_icon_button.dart';
import 'package:ada_rasa_foods/core/widgets/section_card.dart';
import 'package:ada_rasa_foods/features/cart/domain/cart.dart';
import 'package:ada_rasa_foods/features/cart/domain/cart_item.dart';
import 'package:ada_rasa_foods/features/cart/presentation/cart_cubit.dart';
import 'package:ada_rasa_foods/features/cart/presentation/cart_screen.dart';
import 'package:ada_rasa_foods/features/cart/presentation/cart_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockCartCubit extends MockCubit<CartState> implements CartCubit {}

const chicken = CartItem(
  dishId: 'd1',
  name: 'Chicken Kottu',
  price: 1200,
  quantity: 2,
);

const egg = CartItem(dishId: 'd2', name: 'Egg Kottu', price: 950);

CartState cartWith({
  List<CartItem> items = const [chicken, egg],
  CartRestaurantStatus status = CartRestaurantStatus.open,
  Set<String> unavailable = const {},
}) {
  return CartState(
    userId: 'u1',
    cart: Cart(
      restaurantId: 'r1',
      restaurantName: 'Kottu Corner',
      items: items,
    ),
    restaurantStatus: status,
    unavailableDishIds: unavailable,
  );
}

void main() {
  late MockCartCubit cart;

  setUp(() => cart = MockCartCubit());

  Future<void> show(WidgetTester tester, CartState state) async {
    // 360 x 800 points.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    when(() => cart.state).thenReturn(state);

    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push(AppRoutes.cart),
              child: const Text('Open cart'),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.cart,
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: AppRoutes.checkout,
          builder: (context, state) =>
              const Scaffold(body: Text('Checkout page')),
        ),
        GoRoute(
          path: '${AppRoutes.customer}/restaurant/:id',
          builder: (context, state) =>
              const Scaffold(body: Text('Restaurant page')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      BlocProvider<CartCubit>.value(
        value: cart,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => AppThemeByWidth(child: child!),
        ),
      ),
    );
    await tester.tap(find.text('Open cart'));
    await tester.pumpAndSettle();
  }

  // The orange Checkout button at the bottom.
  FilledButton checkoutButton(WidgetTester tester) {
    return tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Checkout'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
  }

  group('empty cart', () {
    testWidgets('shows a big cart icon and Browse restaurants', (
      tester,
    ) async {
      await show(tester, const CartState(userId: 'u1'));

      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart_rounded), findsOneWidget);
      expect(find.text('Browse restaurants'), findsOneWidget);
      expect(find.byTooltip('Clear cart'), findsNothing);
      expect(find.text('Checkout'), findsNothing);
    });

    testWidgets('Browse restaurants goes back', (tester) async {
      await show(tester, const CartState(userId: 'u1'));

      await tester.tap(find.text('Browse restaurants'));
      await tester.pumpAndSettle();

      expect(find.text('Open cart'), findsOneWidget);
    });
  });

  group('cart with dishes', () {
    testWidgets('shows the restaurant card and each dish', (tester) async {
      await show(tester, cartWith());

      expect(find.text('Kottu Corner'), findsOneWidget);
      expect(find.text('Pickup order'), findsOneWidget);
      expect(find.text('Chicken Kottu'), findsOneWidget);
      expect(find.text('Egg Kottu'), findsOneWidget);
    });

    testWidgets('a dish price is its line total, in orange', (tester) async {
      await show(tester, cartWith());

      final line = tester.widget<Text>(find.text('Rs. 2,400'));
      expect(line.style?.color, AppTheme.brandOrange);
      expect(find.text('Rs. 1,200 each'), findsOneWidget);
      // One of a dish needs no "each" line.
      expect(find.text('Rs. 950 each'), findsNothing);
    });

    testWidgets('the summary card shows the items and the total', (
      tester,
    ) async {
      await show(tester, cartWith());

      expect(find.byType(SectionCard), findsOneWidget);
      expect(find.text('Order summary'), findsOneWidget);
      expect(find.text('3 items'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Rs. 3,350'), findsWidgets);
    });

    testWidgets('the Checkout button shows the total', (tester) async {
      await show(tester, cartWith());

      final button = find.ancestor(
        of: find.text('Checkout'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      );
      expect(
        find.descendant(of: button, matching: find.text('Rs. 3,350')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: button,
          matching: find.byIcon(Icons.arrow_forward_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Checkout opens the checkout page', (tester) async {
      await show(tester, cartWith());

      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();

      expect(find.text('Checkout page'), findsOneWidget);
    });

    testWidgets('tapping the restaurant card opens its menu', (tester) async {
      await show(tester, cartWith());

      await tester.tap(find.text('Pickup order'));
      await tester.pumpAndSettle();

      expect(find.text('Restaurant page'), findsOneWidget);
    });
  });

  group('clear and remove', () {
    testWidgets('Clear cart is a soft red round button', (tester) async {
      await show(tester, cartWith());

      final circle = tester.widget<RoundIconCircle>(
        find.descendant(
          of: find.byTooltip('Clear cart'),
          matching: find.byType(RoundIconCircle),
        ),
      );
      expect(circle.style, RoundIconStyle.danger);
    });

    testWidgets('Clear cart asks first, and Clear clears it', (tester) async {
      await show(tester, cartWith());

      await tester.tap(find.byTooltip('Clear cart'));
      await tester.pumpAndSettle();
      expect(find.text('Clear your cart?'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      verify(() => cart.clear()).called(1);
    });

    testWidgets('Cancel keeps the cart', (tester) async {
      await show(tester, cartWith());

      await tester.tap(find.byTooltip('Clear cart'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => cart.clear());
    });

    testWidgets('the red bin asks, then removes that dish', (tester) async {
      await show(tester, cartWith());

      await tester.tap(find.byTooltip('Remove').first);
      await tester.pumpAndSettle();
      expect(find.text('Remove Chicken Kottu?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      verify(() => cart.remove('d1')).called(1);
    });

    testWidgets('the bin is red', (tester) async {
      await show(tester, cartWith());

      final bin = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byIcon(Icons.delete_rounded).first,
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(bin.color, AppTheme.dangerRed);
    });
  });

  group('problems', () {
    testWidgets('a closed restaurant: red banner and no Checkout', (
      tester,
    ) async {
      await show(tester, cartWith(status: CartRestaurantStatus.closed));

      expect(
        find.text('Kottu Corner is closed now. You can order when it opens.'),
        findsOneWidget,
      );
      expect(find.text('The restaurant is closed now.'), findsOneWidget);
      expect(checkoutButton(tester).onPressed, isNull);
      // Faded dishes have no stepper.
      expect(find.byTooltip('More'), findsNothing);
    });

    testWidgets('a dish not available: label, crossed price, no Checkout', (
      tester,
    ) async {
      await show(tester, cartWith(unavailable: {'d2'}));

      expect(find.text('Not available now'), findsOneWidget);
      final price = tester.widget<Text>(find.text('Rs. 950'));
      expect(price.style?.decoration, TextDecoration.lineThrough);
      expect(
        find.text('Remove the dishes that are not available to checkout.'),
        findsOneWidget,
      );
      expect(checkoutButton(tester).onPressed, isNull);
    });

    testWidgets('the not available dish is not in the total', (tester) async {
      await show(tester, cartWith(unavailable: {'d2'}));

      expect(find.text('2 items'), findsOneWidget);
      expect(find.text('Rs. 2,400'), findsWidgets);
    });

    testWidgets('a long dish name fits with no overflow', (tester) async {
      await show(
        tester,
        cartWith(
          items: const [
            CartItem(
              dishId: 'd9',
              name: 'Extra Large Chicken and Cheese Kottu with Egg and '
                  'Spicy Curry Sauce',
              price: 2400,
              quantity: 3,
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}