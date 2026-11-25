import 'package:ada_rasa_foods/core/router/app_router.dart';
import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/round_icon_button.dart';
import 'package:ada_rasa_foods/features/cart/domain/cart.dart';
import 'package:ada_rasa_foods/features/cart/domain/cart_item.dart';
import 'package:ada_rasa_foods/features/cart/presentation/cart_cubit.dart';
import 'package:ada_rasa_foods/features/cart/presentation/cart_icon_button.dart';
import 'package:ada_rasa_foods/features/cart/presentation/cart_state.dart';
import 'package:ada_rasa_foods/features/cart/presentation/fly_to_cart.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockCartCubit extends MockCubit<CartState> implements CartCubit {}

// A cart from Kottu Corner with these items.
CartState cartWith(
  List<CartItem> items, {
  CartRestaurantStatus status = CartRestaurantStatus.open,
}) {
  return CartState(
    userId: 'u1',
    cart: Cart(
      restaurantId: 'r1',
      restaurantName: 'Kottu Corner',
      items: items,
    ),
    restaurantStatus: status,
  );
}

const chickenKottu = CartItem(
  dishId: 'd1',
  name: 'Chicken Kottu',
  price: 1200,
  quantity: 2,
);

void main() {
  late MockCartCubit cart;

  setUp(() => cart = MockCartCubit());

  Future<void> show(
    WidgetTester tester,
    CartState state, {
    RoundIconStyle style = RoundIconStyle.soft,
  }) async {
    // Redmi size: about 393 points wide.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    when(() => cart.state).thenReturn(state);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            appBar: AppBar(
              title: const Text('Home'),
              actions: [CartIconButton(style: style)],
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.cart,
          builder: (context, state) =>
              const Scaffold(body: Text('Cart page')),
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
    await tester.pump();
  }

  Badge badge(WidgetTester tester) => tester.widget<Badge>(find.byType(Badge));

  group('CartIconButton', () {
    testWidgets('shows a rounded cart in a soft round circle', (
      tester,
    ) async {
      await show(tester, const CartState(userId: 'u1'));

      expect(find.byIcon(Icons.shopping_cart_rounded), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);

      final circle = find.byType(RoundIconCircle);
      expect(circle, findsOneWidget);
      expect(tester.getSize(circle), const Size(38, 38));
    });

    testWidgets('is soft orange by default', (tester) async {
      await show(tester, const CartState(userId: 'u1'));

      final circle = tester.widget<RoundIconCircle>(
        find.byType(RoundIconCircle),
      );
      expect(circle.style, RoundIconStyle.soft);
    });

    testWidgets('on a photo it is a white circle', (tester) async {
      await show(
        tester,
        cartWith([chickenKottu]),
        style: RoundIconStyle.onPhoto,
      );

      final circle = tester.widget<RoundIconCircle>(
        find.byType(RoundIconCircle),
      );
      expect(circle.style, RoundIconStyle.onPhoto);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('an empty cart shows no badge', (tester) async {
      await show(tester, const CartState(userId: 'u1'));

      expect(badge(tester).isLabelVisible, isFalse);
    });

    testWidgets('shows the number of items on an orange badge', (
      tester,
    ) async {
      await show(tester, cartWith([chickenKottu]));

      expect(badge(tester).isLabelVisible, isTrue);
      expect(badge(tester).backgroundColor, AppTheme.brandOrange);
      expect(find.text('2'), findsOneWidget);
      expect(find.byTooltip('Cart'), findsOneWidget);
    });

    testWidgets('more than 99 items shows 99+', (tester) async {
      final items = [
        for (var i = 1; i <= 6; i++)
          CartItem(dishId: 'd$i', name: 'Dish $i', price: 500, quantity: 20),
      ];
      await show(tester, cartWith(items));

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('a closed restaurant shows a red "!" badge', (tester) async {
      await show(
        tester,
        cartWith([chickenKottu], status: CartRestaurantStatus.closed),
      );

      expect(find.text('!'), findsOneWidget);
      expect(find.text('2'), findsNothing);
      expect(badge(tester).backgroundColor, Colors.red.shade700);
      expect(find.byTooltip('Cart needs your attention'), findsOneWidget);
    });

    testWidgets('tapping it opens the cart page', (tester) async {
      await show(tester, cartWith([chickenKottu]));

      await tester.tap(find.byType(CartIconButton));
      await tester.pumpAndSettle();

      expect(find.text('Cart page'), findsOneWidget);
    });
  });

  group('fly target with tabs', () {
    const stepperKey = Key('stepper');

    // Like the app: a tab with its own navigator, inside the main one.
    Future<GlobalKey<NavigatorState>> showTab(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      when(() => cart.state).thenReturn(cartWith([chickenKottu]));
      // Flights need a short real gap between them, even across tests.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );

      final rootKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        BlocProvider<CartCubit>.value(
          value: cart,
          child: MaterialApp(
            navigatorKey: rootKey,
            builder: (context, child) => AppThemeByWidth(child: child!),
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(actions: const [CartIconButton()]),
                  body: const Center(
                    child: SizedBox(key: stepperKey, width: 60, height: 60),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return rootKey;
    }

    // Lets the photo land and the bin close.
    Future<void> finish(WidgetTester tester) async {
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('on the tab page itself, minus shows the bin', (
      tester,
    ) async {
      await showTab(tester);

      flyToBin(tester.element(find.byKey(stepperKey)), imageUrl: '');
      await tester.pump();

      // The cart icon and the bin.
      expect(find.byType(RoundIconCircle), findsNWidgets(2));
      await finish(tester);
      expect(find.byType(RoundIconCircle), findsOneWidget);
    });

    testWidgets('a page over the tabs (the cart page) shows no bin', (
      tester,
    ) async {
      final rootKey = await showTab(tester);

      // Like the cart page: opened on the main navigator, over the tab.
      rootKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Center(
              child: SizedBox(key: Key('cart row'), width: 60, height: 60),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = tester.element(find.byKey(const Key('cart row')));
      flyToBin(row, imageUrl: '');
      flyToCart(row, imageUrl: '');
      await tester.pump();

      expect(find.byType(RoundIconCircle), findsNothing);
      await finish(tester);
    });
  });
}