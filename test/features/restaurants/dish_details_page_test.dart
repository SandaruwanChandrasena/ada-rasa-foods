import 'package:ada_rasa_foods/features/cart/presentation/cart_cubit.dart';
import 'package:ada_rasa_foods/features/cart/presentation/cart_state.dart';
import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:ada_rasa_foods/features/menu/presentation/dish_photo_hero.dart';
import 'package:ada_rasa_foods/features/menu/presentation/dish_row.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/dish_details_page.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/restaurant_detail_cubit.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/restaurant_detail_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockRestaurantDetailCubit extends MockCubit<RestaurantDetailState>
    implements RestaurantDetailCubit {}

class MockCartCubit extends MockCubit<CartState> implements CartCubit {}

const kottuCorner = Restaurant(
  id: 'r1',
  name: 'Kottu Corner',
  cuisine: 'Sri Lankan',
  ownerId: 'o1',
  address: 'Colombo',
  latitude: 6.9,
  longitude: 79.8,
);

const closedCorner = Restaurant(
  id: 'r1',
  name: 'Kottu Corner',
  cuisine: 'Sri Lankan',
  ownerId: 'o1',
  address: 'Colombo',
  latitude: 6.9,
  longitude: 79.8,
  isOpen: false,
);

// Longer than 2 lines on a phone, to check the full text shows.
const longText = 'Chopped roti with chicken, egg, leeks, carrot and our '
    'own spicy curry sauce. Made fresh on a hot iron plate, the way it '
    'is done on the streets of Colombo. Ask for extra cheese if you like.';

const chickenKottu = Dish(
  id: 'd1',
  restaurantId: 'r1',
  name: 'Chicken Kottu',
  price: 1200,
  category: 'Kottu',
  description: longText,
);

const soldOut = Dish(
  id: 'd1',
  restaurantId: 'r1',
  name: 'Chicken Kottu',
  price: 1200,
  category: 'Kottu',
  available: false,
);

RestaurantDetailState loaded({
  Restaurant restaurant = kottuCorner,
  List<Dish> dishes = const [chickenKottu],
}) {
  return RestaurantDetailState(
    status: RestaurantDetailStatus.loaded,
    restaurant: restaurant,
    dishes: dishes,
  );
}

void main() {
  late MockRestaurantDetailCubit detail;
  late MockCartCubit cart;

  setUpAll(() => registerFallbackValue(chickenKottu));

  setUp(() {
    detail = MockRestaurantDetailCubit();
    cart = MockCartCubit();
    when(() => cart.state).thenReturn(const CartState(userId: 'u1'));
    when(
      () => cart.addDish(any(), restaurantName: any(named: 'restaurantName')),
    ).thenReturn(AddToCartResult.added);
    when(() => detail.start(any())).thenAnswer((_) async {});
  });

  Future<void> show(WidgetTester tester, RestaurantDetailState state) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    when(() => detail.state).thenReturn(state);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<RestaurantDetailCubit>.value(value: detail),
          BlocProvider<CartCubit>.value(value: cart),
        ],
        child: const MaterialApp(
          home: DishDetailsView(restaurantId: 'r1', dishId: 'd1'),
        ),
      ),
    );
    await tester.pump();
  }

  // The Add button, found by its text.
  FilledButton addButton(WidgetTester tester) => tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Add'),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        ),
      );

  group('dish details page', () {
    testWidgets('shows a spinner while loading', (tester) async {
      await show(tester, const RestaurantDetailState());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the name, price, category and restaurant',
        (tester) async {
      await show(tester, loaded());

      // The name is in the top bar and in the page.
      expect(find.text('Chicken Kottu'), findsWidgets);
      expect(find.text('Rs. 1,200'), findsOneWidget);
      expect(find.text('Kottu'), findsOneWidget);
      expect(find.text('From Kottu Corner'), findsOneWidget);
    });

    testWidgets('shows the full description, not cut', (tester) async {
      await show(tester, loaded());

      final text = tester.widget<Text>(find.text(longText));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
    });

    testWidgets('Add works and adds the dish to the cart', (tester) async {
      await show(tester, loaded());

      expect(find.text('Add to your order'), findsOneWidget);
      expect(addButton(tester).onPressed, isNotNull);
      await tester.tap(find.text('Add'));
      await tester.pump();

      verify(
        () => cart.addDish(chickenKottu, restaurantName: 'Kottu Corner'),
      ).called(1);
    });

    testWidgets('a dish not available shows the label and no Add',
        (tester) async {
      await show(tester, loaded(dishes: const [soldOut]));

      expect(find.text('Not available now'), findsOneWidget);
      expect(addButton(tester).onPressed, isNull);
    });

    testWidgets('a closed restaurant shows Closed now and no Add',
        (tester) async {
      await show(tester, loaded(restaurant: closedCorner));

      expect(find.text('Closed now'), findsOneWidget);
      expect(addButton(tester).onPressed, isNull);
    });

    testWidgets('an open restaurant and available dish show no label',
        (tester) async {
      await show(tester, loaded());

      expect(find.text('Not available now'), findsNothing);
      expect(find.text('Closed now'), findsNothing);
    });

    testWidgets('a deleted dish says it is no longer on the menu',
        (tester) async {
      await show(tester, loaded(dishes: const []));

      expect(find.text('This dish is no longer on the menu.'), findsOneWidget);
    });

    testWidgets('a missing restaurant says so', (tester) async {
      await show(
        tester,
        const RestaurantDetailState(status: RestaurantDetailStatus.notFound),
      );

      expect(find.text('This restaurant is not available.'), findsOneWidget);
    });

    testWidgets('a load error shows Retry, and Retry starts again',
        (tester) async {
      await show(
        tester,
        const RestaurantDetailState(
          status: RestaurantDetailStatus.failure,
          errorMessage: 'No internet connection. Please try again.',
        ),
      );

      expect(
        find.text('No internet connection. Please try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();

      verify(() => detail.start('r1')).called(1);
    });

    testWidgets('the big photo has the dish Hero tag', (tester) async {
      await show(tester, loaded());

      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.tag, DishPhotoHero.tagFor('d1'));
    });

    testWidgets('it updates live when the dish becomes not available',
        (tester) async {
      whenListen(
        detail,
        Stream.fromIterable([loaded(dishes: const [soldOut])]),
        initialState: loaded(),
      );
      await show(tester, loaded());
      await tester.pumpAndSettle();

      expect(find.text('Not available now'), findsOneWidget);
      expect(addButton(tester).onPressed, isNull);
    });
  });

  group('dish row card', () {
    // Our card: a Material with a grey border. Buttons have no border.
    Finder borderedCard() => find.descendant(
          of: find.byType(DishRow),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Material &&
                widget.shape is RoundedRectangleBorder &&
                (widget.shape! as RoundedRectangleBorder).side !=
                    BorderSide.none,
          ),
        );

    Future<void> showRow(
      WidgetTester tester, {
      VoidCallback? onTap,
      VoidCallback? onTrailing,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DishRow(
              dish: chickenKottu,
              onTap: onTap,
              trailing: TextButton(
                onPressed: onTrailing ?? () {},
                child: const Text('Add'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('tapping the name opens the dish', (tester) async {
      var opened = 0;
      await showRow(tester, onTap: () => opened++);

      await tester.tap(find.text('Chicken Kottu'));
      await tester.pump();

      expect(opened, 1);
    });

    testWidgets('tapping Add does not open the dish', (tester) async {
      var opened = 0;
      var added = 0;
      await showRow(
        tester,
        onTap: () => opened++,
        onTrailing: () => added++,
      );

      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(added, 1);
      expect(opened, 0);
    });

    testWidgets('with a tap, the row is a card with a border',
        (tester) async {
      await showRow(tester, onTap: () {});

      expect(borderedCard(), findsOneWidget);
    });

    testWidgets('with a tap, the photo can fly (Hero)', (tester) async {
      await showRow(tester, onTap: () {});

      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.tag, DishPhotoHero.tagFor('d1'));
    });

    testWidgets('without a tap, the photo does not fly', (tester) async {
      await showRow(tester);

      expect(find.byType(Hero), findsNothing);
    });

    testWidgets('without a tap, the row has no card (owner Menu tab)',
        (tester) async {
      await showRow(tester);

      expect(borderedCard(), findsNothing);
    });
  });
}