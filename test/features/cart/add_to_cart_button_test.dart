import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/features/cart/domain/cart.dart';
import 'package:ada_rasa_foods/features/cart/domain/cart_item.dart';
import 'package:ada_rasa_foods/features/cart/presentation/add_to_cart_button.dart';
import 'package:ada_rasa_foods/features/cart/presentation/cart_cubit.dart';
import 'package:ada_rasa_foods/features/cart/presentation/cart_state.dart';
import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockCartCubit extends MockCubit<CartState> implements CartCubit {}

const kottu = Dish(
  id: 'd1',
  restaurantId: 'r1',
  name: 'Chicken Kottu',
  price: 1200,
  category: 'Kottu',
);

CartState cartWith(int quantity) {
  return CartState(
    userId: 'u1',
    cart: Cart(
      restaurantId: 'r1',
      restaurantName: 'Kottu Corner',
      items: [
        CartItem(
          dishId: 'd1',
          name: 'Chicken Kottu',
          price: 1200,
          quantity: quantity,
        ),
      ],
    ),
  );
}

void main() {
  late MockCartCubit cart;

  setUpAll(() => registerFallbackValue(kottu));

  setUp(() {
    cart = MockCartCubit();
    when(
      () => cart.addDish(any(), restaurantName: any(named: 'restaurantName')),
    ).thenReturn(AddToCartResult.added);
  });

  Future<void> show(
    WidgetTester tester,
    CartState state, {
    bool enabled = true,
  }) async {
    // 360 x 800 points.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    when(() => cart.state).thenReturn(state);
    await tester.pumpWidget(
      BlocProvider<CartCubit>.value(
        value: cart,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: AddToCartButton(
                dish: kottu,
                restaurantName: 'Kottu Corner',
                enabled: enabled,
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration stepperBox(WidgetTester tester) {
    final box = tester.widget<Container>(
      find
          .ancestor(of: find.text('2'), matching: find.byType(Container))
          .first,
    );
    return box.decoration! as BoxDecoration;
  }

  group('AddToCartButton', () {
    testWidgets('Add has a rounded plus icon', (tester) async {
      await show(tester, const CartState(userId: 'u1'));

      expect(find.text('Add'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('tapping Add adds the dish', (tester) async {
      await show(tester, const CartState(userId: 'u1'));

      await tester.tap(find.text('Add'));
      await tester.pump();

      verify(
        () => cart.addDish(kottu, restaurantName: 'Kottu Corner'),
      ).called(1);
    });

    testWidgets('in the cart: a soft orange stepper with no border', (
      tester,
    ) async {
      await show(tester, cartWith(2));

      final box = stepperBox(tester);
      expect(box.color, AppTheme.softOrange);
      expect(box.border, isNull);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('the amount is dark orange and bold', (tester) async {
      await show(tester, cartWith(2));

      final amount = tester.widget<Text>(find.text('2'));
      expect(amount.style?.color, AppTheme.deepOrange);
      expect(amount.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('minus and plus change the amount', (tester) async {
      await show(tester, cartWith(2));

      await tester.tap(find.byTooltip('More'));
      await tester.tap(find.byTooltip('Less'));
      await tester.pump();

      verify(() => cart.increase('d1')).called(1);
      verify(() => cart.decrease('d1')).called(1);
    });

    testWidgets('at the most allowed, plus cannot be tapped', (tester) async {
      await show(tester, cartWith(Cart.maxQuantity));

      final plus = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.add_rounded),
          matching: find.byType(IconButton),
        ),
      );
      expect(plus.onPressed, isNull);
    });

    testWidgets('when not enabled, a grey Add shows even if in the cart', (
      tester,
    ) async {
      await show(tester, cartWith(2), enabled: false);

      expect(find.text('Add'), findsOneWidget);
      expect(find.text('2'), findsNothing);
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Add'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  
    testWidgets('Add shows no "Added to cart" pop-up anymore', (
      tester,
    ) async {
      await show(tester, const CartState(userId: 'u1'));

      await tester.tap(find.text('Add'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(
        () => cart.addDish(kottu, restaurantName: 'Kottu Corner'),
      ).called(1);
      expect(find.text('Added to cart'), findsNothing);
    });
  });
}