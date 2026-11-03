import 'package:ada_rasa_foods/features/auth/domain/app_user.dart';
import 'package:ada_rasa_foods/features/auth/domain/user_role.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:ada_rasa_foods/features/menu/presentation/dish_form_screen.dart';
import 'package:ada_rasa_foods/features/menu/presentation/menu_manage_cubit.dart';
import 'package:ada_rasa_foods/features/menu/presentation/menu_manage_state.dart';
import 'package:ada_rasa_foods/features/orders/presentation/restaurant_orders_cubit.dart';
import 'package:ada_rasa_foods/features/orders/presentation/restaurant_orders_state.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/my_restaurant_cubit.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/restaurant_photo_cubit.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/restaurant_shell.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

class MockBoardCubit extends MockCubit<RestaurantOrdersState>
    implements RestaurantOrdersCubit {}

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

void main() {
  late MockAuthCubit authCubit;
  late MockBoardCubit board;
  late MockMyRestaurantCubit myRestaurant;
  late MockMenuManageCubit menu;
  late MockRestaurantPhotoCubit photo;
  late List<DishFormArgs> opened;

  setUp(() {
    authCubit = MockAuthCubit();
    board = MockBoardCubit();
    myRestaurant = MockMyRestaurantCubit();
    menu = MockMenuManageCubit();
    photo = MockRestaurantPhotoCubit();
    opened = [];
    when(() => authCubit.state)
        .thenReturn(const AuthState.authenticated(owner));
    when(() => authCubit.signOut()).thenAnswer((_) async {});
    when(() => board.state).thenReturn(emptyBoard);
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

  // Only what is really on screen. The hidden tab stays in the tree.
  Finder onScreen(String text) => find.text(text).hitTestable();

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the bottom bar has Orders and Menu', (tester) async {
    await show(tester);

    final bar = find.byType(NavigationBar);
    expect(
      find.descendant(of: bar, matching: find.text('Orders')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bar, matching: find.text('Menu')),
      findsOneWidget,
    );
  });

  testWidgets('Orders opens first', (tester) async {
    await show(tester);

    expect(onScreen('Kottu Corner'), findsOneWidget);
    expect(onScreen('No new orders.'), findsOneWidget);
    expect(onScreen('Cheese Kottu'), findsNothing);
  });

  testWidgets('Menu shows the dishes', (tester) async {
    await show(tester);

    await openTab(tester, 'Menu');

    expect(onScreen('Cheese Kottu'), findsOneWidget);
    expect(onScreen('Add dish'), findsOneWidget);
    expect(onScreen('No new orders.'), findsNothing);
  });

  testWidgets('Menu shows the restaurant photo card', (tester) async {
    await show(tester);

    await openTab(tester, 'Menu');

    expect(onScreen('Restaurant photo'), findsOneWidget);
    expect(onScreen('Choose photo'), findsOneWidget);
  });

  testWidgets('Orders brings the board back', (tester) async {
    await show(tester);
    await openTab(tester, 'Menu');

    await openTab(tester, 'Orders');

    expect(onScreen('No new orders.'), findsOneWidget);
    expect(onScreen('Cheese Kottu'), findsNothing);
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

  testWidgets('a new order alert shows on the Menu tab too',
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
    await openTab(tester, 'Menu');

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('New order #XYZ789'), findsOneWidget);
  });

  testWidgets('Sign out works on the Menu tab', (tester) async {
    await show(tester);
    await openTab(tester, 'Menu');

    await tester.tap(find.byTooltip('Sign out').hitTestable());

    verify(() => authCubit.signOut()).called(1);
  });
}