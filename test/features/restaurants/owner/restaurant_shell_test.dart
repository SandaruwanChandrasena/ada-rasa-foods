import 'package:ada_rasa_foods/features/auth/domain/app_user.dart';
import 'package:ada_rasa_foods/features/auth/domain/user_role.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
import 'package:ada_rasa_foods/features/dashboard/domain/day_summary.dart';
import 'package:ada_rasa_foods/features/dashboard/presentation/owner_dashboard_cubit.dart';
import 'package:ada_rasa_foods/features/dashboard/presentation/owner_dashboard_state.dart';
import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:ada_rasa_foods/features/menu/presentation/dish_form_screen.dart';
import 'package:ada_rasa_foods/features/menu/presentation/menu_manage_cubit.dart';
import 'package:ada_rasa_foods/features/menu/presentation/menu_manage_state.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_item.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:ada_rasa_foods/features/orders/presentation/board/board_top_bar.dart';
import 'package:ada_rasa_foods/features/orders/presentation/board/restaurant_orders_cubit.dart';
import 'package:ada_rasa_foods/features/orders/presentation/board/restaurant_orders_state.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/owner/my_restaurant_cubit.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/owner/restaurant_photo_cubit.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/owner/owner_profile_page.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/owner/restaurant_shell.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

class MockBoardCubit extends MockCubit<RestaurantOrdersState>
    implements RestaurantOrdersCubit {}

class MockDashboardCubit extends MockCubit<OwnerDashboardState>
    implements OwnerDashboardCubit {}

class MockMyRestaurantCubit extends MockCubit<MyRestaurantState>
    implements MyRestaurantCubit {}

class MockMenuManageCubit extends MockCubit<MenuManageState>
    implements MenuManageCubit {}

class MockRestaurantPhotoCubit extends MockCubit<RestaurantPhotoState>
    implements RestaurantPhotoCubit {}

const owner = AppUser(
  uid: 'o1',
  name: 'Owner',
  email: 'owner@test.com',
  role: UserRole.restaurant,
  restaurantId: 'r1',
);

const kottu = Restaurant(
  id: 'r1',
  name: 'Kottu Corner',
  cuisine: 'Sri Lankan',
  ownerId: 'o1',
  address: 'Colombo',
  latitude: 6.9,
  longitude: 79.8,
);

const cheeseKottu = Dish(
  id: 'd1',
  restaurantId: 'r1',
  name: 'Cheese Kottu',
  price: 1500,
  category: 'Kottu',
);

const emptyBoard = RestaurantOrdersState(
  view: BoardView.loaded,
  doneLoaded: true,
);

const today = OwnerDashboardState(
  view: DashboardView.loaded,
  summary: DaySummary(sales: 8400, doneCount: 12, newCount: 1),
);

const placedOrder = FoodOrder(
  id: 'abc123xyz',
  customerId: 'u1',
  customerName: 'Nimal',
  customerPhone: '0712345678',
  restaurantId: 'r1',
  restaurantName: 'Kottu Corner',
  restaurantAddress: 'Colombo',
  items: [
    OrderItem(dishId: 'd1', name: 'Cheese Kottu', price: 1500, quantity: 1),
  ],
  total: 1500,
  paymentMethod: PaymentMethod.cash,
  paymentStatus: PaymentStatus.pending,
  status: OrderStatus.placed,
);

void main() {
  late MockAuthCubit authCubit;
  late MockBoardCubit board;
  late MockDashboardCubit dashboard;
  late MockMyRestaurantCubit myRestaurant;
  late MockMenuManageCubit menu;
  late MockRestaurantPhotoCubit photo;
  late List<DishFormArgs> opened;

  setUp(() {
    authCubit = MockAuthCubit();
    board = MockBoardCubit();
    dashboard = MockDashboardCubit();
    myRestaurant = MockMyRestaurantCubit();
    menu = MockMenuManageCubit();
    photo = MockRestaurantPhotoCubit();
    opened = [];
    when(() => authCubit.state)
        .thenReturn(const AuthState.authenticated(owner));
    when(() => authCubit.signOut()).thenAnswer((_) async {});
    when(() => board.state).thenReturn(emptyBoard);
    when(() => dashboard.state).thenReturn(today);
    when(() => myRestaurant.state).thenReturn(
      const MyRestaurantState(
        view: MyRestaurantView.loaded,
        restaurant: kottu,
      ),
    );
    when(() => menu.state).thenReturn(
      const MenuManageState(view: MenuView.loaded, dishes: [cheeseKottu]),
    );
    when(() => photo.state).thenReturn(const RestaurantPhotoState());
  });

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<RestaurantOrdersCubit>.value(value: board),
          BlocProvider<OwnerDashboardCubit>.value(value: dashboard),
          BlocProvider<MyRestaurantCubit>.value(value: myRestaurant),
          BlocProvider<MenuManageCubit>.value(value: menu),
          BlocProvider<RestaurantPhotoCubit>.value(value: photo),
        ],
        child: MaterialApp(
          home: RestaurantShell(
            callPhone: (_) async => true,
            openDish: (_, args) => opened.add(args),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Only what is really on screen. The hidden tabs stay in the tree.
  Finder onScreen(String text) => find.text(text).hitTestable();

  Finder photoCover() =>
      find.byKey(const Key('restaurant-photo-box')).hitTestable();

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  Badge ordersBadge(WidgetTester tester) {
    return tester.widget<Badge>(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(Badge),
      ),
    );
  }

  int selectedTab(WidgetTester tester) {
    return tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .selectedIndex;
  }

  Future<void> tapCard(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)).hitTestable());
    await tester.pumpAndSettle();
  }

  Future<void> tapBoardChip(WidgetTester tester, String label) async {
    await tester.tap(
      find
          .descendant(of: find.byType(BoardChips), matching: find.text(label))
          .hitTestable(),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the bottom bar has Home, Orders, Menu and Profile',
      (tester) async {
    await show(tester);

    final bar = find.byType(NavigationBar);
    for (final label in ['Home', 'Orders', 'Menu', 'Profile']) {
      expect(
        find.descendant(of: bar, matching: find.text(label)),
        findsOneWidget,
      );
    }
  });

  testWidgets('the bottom bar uses rounded icons', (tester) async {
    await show(tester);

    final bar = find.byType(NavigationBar);
    for (final icon in [
      Icons.home_rounded,
      Icons.receipt_long_rounded,
      Icons.restaurant_menu_rounded,
      Icons.person_rounded,
    ]) {
      expect(
        find.descendant(of: bar, matching: find.byIcon(icon)),
        findsOneWidget,
      );
    }
  });

  testWidgets('Home opens first with the numbers of today', (tester) async {
    await show(tester);

    expect(selectedTab(tester), 0);
    expect(onScreen('Hi, Owner'), findsOneWidget);
    expect(onScreen('Rs. 8,400'), findsOneWidget);
    expect(onScreen('No new orders.'), findsNothing);
  });

  testWidgets('Orders shows the board', (tester) async {
    await show(tester);

    await openTab(tester, 'Orders');

    expect(selectedTab(tester), 1);
    expect(onScreen('No new orders.'), findsOneWidget);
    expect(onScreen('Rs. 8,400'), findsNothing);
  });

  testWidgets('Menu shows the dishes', (tester) async {
    await show(tester);

    await openTab(tester, 'Menu');

    expect(onScreen('Cheese Kottu'), findsOneWidget);
    expect(onScreen('Add dish'), findsOneWidget);
    expect(onScreen('Rs. 8,400'), findsNothing);
  });

  testWidgets('Menu no longer has the photo card or Sign out',
      (tester) async {
    await show(tester);

    await openTab(tester, 'Menu');

    expect(photoCover(), findsNothing);
    expect(find.byTooltip('Sign out').hitTestable(), findsNothing);
  });

  testWidgets('Profile shows the photo card and the Open card',
      (tester) async {
    await show(tester);

    await openTab(tester, 'Profile');

    expect(photoCover(), findsOneWidget);
    // The Open card may be below the fold now, so we look in the page.
    expect(
      find.descendant(
        of: find.byType(OwnerProfilePage),
        matching: find.text('Open for orders'),
      ),
      findsOneWidget,
    );
    expect(onScreen('Cheese Kottu'), findsNothing);
  });

  testWidgets('Home brings the numbers back', (tester) async {
    await show(tester);
    await openTab(tester, 'Profile');

    await openTab(tester, 'Home');

    expect(onScreen('Rs. 8,400'), findsOneWidget);
    expect(photoCover(), findsNothing);
  });

  testWidgets('no orange dot when no new order waits', (tester) async {
    await show(tester);

    expect(ordersBadge(tester).isLabelVisible, isFalse);
  });

  testWidgets('an orange dot shows while a new order waits',
      (tester) async {
    when(() => board.state).thenReturn(
      const RestaurantOrdersState(
        view: BoardView.loaded,
        doneLoaded: true,
        open: [placedOrder],
      ),
    );

    await show(tester);

    expect(ordersBadge(tester).isLabelVisible, isTrue);
  });

  group('the Home cards open the Orders board', () {
    testWidgets('New opens the New chip', (tester) async {
      await show(tester);
      await openTab(tester, 'Orders');
      await tapBoardChip(tester, 'Done');
      await openTab(tester, 'Home');

      await tapCard(tester, 'stat-new');

      expect(selectedTab(tester), 1);
      expect(onScreen('No new orders.'), findsOneWidget);
    });

    testWidgets('Active opens the Active chip', (tester) async {
      await show(tester);

      await tapCard(tester, 'stat-active');

      expect(selectedTab(tester), 1);
      expect(onScreen('No active orders.'), findsOneWidget);
    });

    testWidgets('Done opens the Done chip', (tester) async {
      await show(tester);

      await tapCard(tester, 'stat-done');

      expect(selectedTab(tester), 1);
      expect(onScreen('No finished orders yet.'), findsOneWidget);
    });

    testWidgets('the same card works again after a chip change',
        (tester) async {
      await show(tester);
      await tapCard(tester, 'stat-active');
      await tapBoardChip(tester, 'Done');
      await openTab(tester, 'Home');

      await tapCard(tester, 'stat-active');

      expect(onScreen('No active orders.'), findsOneWidget);
      expect(onScreen('No finished orders yet.'), findsNothing);
    });
  });

  group('phone back', () {
    for (final tab in ['Orders', 'Menu', 'Profile']) {
      testWidgets('on $tab goes to Home', (tester) async {
        await show(tester);
        await openTab(tester, tab);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(selectedTab(tester), 0);
        expect(onScreen('Rs. 8,400'), findsOneWidget);
      });
    }
  });

  testWidgets('Add dish opens the dish page with the categories',
      (tester) async {
    await show(tester);
    await openTab(tester, 'Menu');

    await tester.tap(onScreen('Add dish'));
    await tester.pumpAndSettle();

    expect(opened, hasLength(1));
    expect(opened.single.restaurantId, 'r1');
    expect(opened.single.categories, ['Kottu']);
    expect(opened.single.dish, isNull);
  });

  testWidgets('tapping a dish opens it for editing', (tester) async {
    await show(tester);
    await openTab(tester, 'Menu');

    await tester.tap(onScreen('Cheese Kottu'));
    await tester.pumpAndSettle();

    expect(opened.single.dish, cheeseKottu);
  });

  testWidgets('a new order alert shows on the Home tab too',
      (tester) async {
    whenListen(
      board,
      Stream.fromFuture(
        Future<RestaurantOrdersState>.delayed(
          const Duration(seconds: 1),
          () => const RestaurantOrdersState(
            view: BoardView.loaded,
            doneLoaded: true,
            newOrderNumber: 'XYZ789',
            newOrderAlertId: 1,
          ),
        ),
      ),
      initialState: emptyBoard,
    );
    await show(tester);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('New order #XYZ789'), findsOneWidget);
  });

  testWidgets('a new order alert shows on the Profile tab too',
      (tester) async {
    whenListen(
      board,
      Stream.fromFuture(
        Future<RestaurantOrdersState>.delayed(
          const Duration(seconds: 1),
          () => const RestaurantOrdersState(
            view: BoardView.loaded,
            doneLoaded: true,
            newOrderNumber: 'XYZ789',
            newOrderAlertId: 1,
          ),
        ),
      ),
      initialState: emptyBoard,
    );
    await show(tester);
    await openTab(tester, 'Profile');

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('New order #XYZ789'), findsOneWidget);
  });
}