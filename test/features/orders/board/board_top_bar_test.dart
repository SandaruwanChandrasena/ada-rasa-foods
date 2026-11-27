import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_item.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:ada_rasa_foods/features/orders/presentation/board/board_top_bar.dart';
import 'package:ada_rasa_foods/features/orders/presentation/board/restaurant_orders_cubit.dart';
import 'package:ada_rasa_foods/features/orders/presentation/board/restaurant_orders_state.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/owner/my_restaurant_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockBoardCubit extends MockCubit<RestaurantOrdersState>
    implements RestaurantOrdersCubit {}

class MockMyRestaurantCubit extends MockCubit<MyRestaurantState>
    implements MyRestaurantCubit {}

Restaurant kottu({bool isOpen = true}) {
  return Restaurant(
    id: 'r1',
    name: 'Kottu Corner',
    cuisine: 'Sri Lankan',
    ownerId: 'o1',
    address: 'Colombo',
    latitude: 6.9,
    longitude: 79.8,
    isOpen: isOpen,
  );
}

MyRestaurantState shop({bool isOpen = true, bool saving = false}) {
  return MyRestaurantState(
    view: MyRestaurantView.loaded,
    restaurant: kottu(isOpen: isOpen),
    isSaving: saving,
  );
}

FoodOrder order(String id, OrderStatus status) {
  return FoodOrder(
    id: id,
    customerId: 'u1',
    customerName: 'Nimal',
    restaurantId: 'r1',
    restaurantName: 'Kottu Corner',
    restaurantAddress: 'Colombo',
    items: const [
      OrderItem(dishId: 'd1', name: 'Chicken Kottu', price: 1200, quantity: 1),
    ],
    total: 1200,
    paymentMethod: PaymentMethod.cash,
    paymentStatus: PaymentStatus.pending,
    status: status,
  );
}

void main() {
  late MockBoardCubit board;
  late MockMyRestaurantCubit myRestaurant;
  TabController? tabs;

  setUp(() {
    board = MockBoardCubit();
    myRestaurant = MockMyRestaurantCubit();
    tabs = null;
    when(() => board.state).thenReturn(
      const RestaurantOrdersState(view: BoardView.loaded, doneLoaded: true),
    );
    when(() => myRestaurant.state).thenReturn(shop());
    when(() => myRestaurant.setOpen(any())).thenAnswer((_) async {});
  });

  Future<void> show(WidgetTester tester, {bool settle = true}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<RestaurantOrdersCubit>.value(value: board),
          BlocProvider<MyRestaurantCubit>.value(value: myRestaurant),
        ],
        child: MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Builder(
              builder: (context) {
                tabs = DefaultTabController.of(context);
                return Scaffold(
                  appBar: AppBar(actions: const [OpenPill()]),
                  body: const Column(
                    children: [
                      ClosedNote(),
                      BoardChips(),
                      Expanded(
                        child: TabBarView(
                          children: [
                            Text('List 0'),
                            Text('List 1'),
                            Text('List 2'),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
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

  Finder pill() => find.byKey(const Key('open-pill'));

  Color? pillColor(WidgetTester tester) =>
      tester.widget<Material>(pill()).color;

  Color? chipColor(WidgetTester tester, String label) {
    return tester
        .widget<Material>(
          find.ancestor(of: find.text(label), matching: find.byType(Material))
              .first,
        )
        .color;
  }

  group('Open pill', () {
    testWidgets('hidden until the restaurant loads', (tester) async {
      when(() => myRestaurant.state).thenReturn(const MyRestaurantState());

      await show(tester);

      expect(pill(), findsNothing);
    });

    testWidgets('an open restaurant shows a green Open', (tester) async {
      await show(tester);

      expect(find.text('Open'), findsOneWidget);
      expect(pillColor(tester), AppTheme.successBg);
      final text = tester.widget<Text>(find.text('Open'));
      expect(text.style?.color, AppTheme.successGreen);
    });

    testWidgets('a closed restaurant shows a soft red Closed',
        (tester) async {
      when(() => myRestaurant.state).thenReturn(shop(isOpen: false));

      await show(tester);

      expect(find.text('Closed'), findsOneWidget);
      expect(pillColor(tester), AppTheme.dangerBg);
      final text = tester.widget<Text>(find.text('Closed'));
      expect(text.style?.color, AppTheme.dangerRed);
    });

    testWidgets('tapping Open asks first, and Cancel keeps it open',
        (tester) async {
      await show(tester);

      await tester.tap(pill());
      await tester.pumpAndSettle();

      expect(find.text('Close now?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Close now?'), findsNothing);
      verifyNever(() => myRestaurant.setOpen(any()));
    });

    testWidgets('Close in the question closes the restaurant',
        (tester) async {
      await show(tester);

      await tester.tap(pill());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pumpAndSettle();

      verify(() => myRestaurant.setOpen(false)).called(1);
    });

    testWidgets('tapping Closed opens at once, with no question',
        (tester) async {
      when(() => myRestaurant.state).thenReturn(shop(isOpen: false));
      await show(tester);

      await tester.tap(pill());
      await tester.pumpAndSettle();

      expect(find.text('Close now?'), findsNothing);
      verify(() => myRestaurant.setOpen(true)).called(1);
    });

    testWidgets('while saving: a spinner, and a tap does nothing',
        (tester) async {
      when(() => myRestaurant.state).thenReturn(shop(saving: true));
      await show(tester, settle: false);

      expect(
        find.descendant(
          of: pill(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      await tester.tap(pill());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Close now?'), findsNothing);
      verifyNever(() => myRestaurant.setOpen(any()));
    });
  });

  group('Closed note', () {
    testWidgets('hidden while open', (tester) async {
      await show(tester);

      expect(find.text('Closed. No new orders come.'), findsNothing);
    });

    testWidgets('shows in soft red while closed', (tester) async {
      when(() => myRestaurant.state).thenReturn(shop(isOpen: false));

      await show(tester);

      final text = tester.widget<Text>(
        find.text('Closed. No new orders come.'),
      );
      expect(text.style?.color, AppTheme.dangerRed);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
    });

    testWidgets('hidden until the restaurant loads', (tester) async {
      when(() => myRestaurant.state).thenReturn(const MyRestaurantState());

      await show(tester);

      expect(find.text('Closed. No new orders come.'), findsNothing);
    });
  });

  group('Board chips', () {
    testWidgets('show New and Active counts, Done has none',
        (tester) async {
      when(() => board.state).thenReturn(
        RestaurantOrdersState(
          view: BoardView.loaded,
          doneLoaded: true,
          open: [
            order('a1', OrderStatus.placed),
            order('a2', OrderStatus.placed),
            order('a3', OrderStatus.preparing),
          ],
          done: [order('a4', OrderStatus.completed)],
        ),
      );

      await show(tester);

      expect(find.text('New 2'), findsOneWidget);
      expect(find.text('Active 1'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('no number when a list is empty', (tester) async {
      await show(tester);

      expect(find.text('New'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('the first chip is orange, the others grey', (tester) async {
      await show(tester);

      expect(chipColor(tester, 'New'), AppTheme.brandOrange);
      expect(chipColor(tester, 'Active'), isNot(AppTheme.brandOrange));
      expect(chipColor(tester, 'Done'), isNot(AppTheme.brandOrange));
      final text = tester.widget<Text>(find.text('New'));
      expect(text.style?.color, Colors.white);
    });

    testWidgets('tapping Done opens the third list', (tester) async {
      await show(tester);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(tabs!.index, 2);
      expect(find.text('List 2'), findsOneWidget);
      expect(chipColor(tester, 'Done'), AppTheme.brandOrange);
      expect(chipColor(tester, 'New'), isNot(AppTheme.brandOrange));
    });

    testWidgets('a swipe moves the orange chip', (tester) async {
      await show(tester);

      await tester.fling(
        find.byType(TabBarView),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(tabs!.index, 1);
      expect(chipColor(tester, 'Active'), AppTheme.brandOrange);
    });
  });
}