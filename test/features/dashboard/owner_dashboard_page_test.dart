import 'package:ada_rasa_foods/features/auth/domain/app_user.dart';
import 'package:ada_rasa_foods/features/auth/domain/user_role.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
import 'package:ada_rasa_foods/features/dashboard/domain/day_summary.dart';
import 'package:ada_rasa_foods/features/dashboard/presentation/dashboard_cards.dart';
import 'package:ada_rasa_foods/features/dashboard/presentation/owner_dashboard_cubit.dart';
import 'package:ada_rasa_foods/features/dashboard/presentation/owner_dashboard_page.dart';
import 'package:ada_rasa_foods/features/dashboard/presentation/owner_dashboard_state.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/owner/my_restaurant_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

class MockDashboardCubit extends MockCubit<OwnerDashboardState>
    implements OwnerDashboardCubit {}

class MockMyRestaurantCubit extends MockCubit<MyRestaurantState>
    implements MyRestaurantCubit {}

const owner = AppUser(
  uid: 'o1',
  name: 'Nimal Perera',
  email: 'owner@test.com',
  role: UserRole.restaurant,
);

const kottu = Restaurant(
  id: 'r1',
  name: 'Kottu Corner',
  cuisine: 'Sri Lankan',
  ownerId: 'o1',
  address: 'Colombo',
  latitude: 6.9,
  longitude: 79.8,
  isOpen: true,
);

OwnerDashboardState loaded(DaySummary summary) {
  return OwnerDashboardState(view: DashboardView.loaded, summary: summary);
}

const busyDay = DaySummary(
  sales: 8400,
  doneCount: 12,
  newCount: 2,
  activeCount: 3,
  droppedCount: 1,
  topDishes: [
    TopDish(dishId: 'd1', name: 'Chicken Kottu', quantity: 5),
    TopDish(dishId: 'd2', name: 'Cheese Kottu', quantity: 3),
  ],
);

void main() {
  late MockAuthCubit authCubit;
  late MockDashboardCubit dashboard;
  late MockMyRestaurantCubit myRestaurant;
  late List<int> openedChips;

  setUp(() {
    authCubit = MockAuthCubit();
    dashboard = MockDashboardCubit();
    myRestaurant = MockMyRestaurantCubit();
    openedChips = [];
    when(() => authCubit.state)
        .thenReturn(const AuthState.authenticated(owner));
    when(() => myRestaurant.state).thenReturn(
      const MyRestaurantState(
        view: MyRestaurantView.loaded,
        restaurant: kottu,
      ),
    );
  });

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Widget app({bool canOpen = true, double textScale = 1}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<OwnerDashboardCubit>.value(value: dashboard),
        BlocProvider<MyRestaurantCubit>.value(value: myRestaurant),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: OwnerDashboardView(
          onOpenBoard: canOpen ? openedChips.add : null,
        ),
      ),
    );
  }

  Future<void> show(
    WidgetTester tester,
    OwnerDashboardState state, {
    bool canOpen = true,
    double textScale = 1,
  }) async {
    phoneSize(tester);
    when(() => dashboard.state).thenReturn(state);
    await tester.pumpWidget(app(canOpen: canOpen, textScale: textScale));
    await tester.pumpAndSettle();
  }

  Finder inCard(String key, Finder matching) {
    return find.descendant(of: find.byKey(Key(key)), matching: matching);
  }

  testWidgets('shows a spinner while loading', (tester) async {
    phoneSize(tester);
    when(() => dashboard.state).thenReturn(const OwnerDashboardState());
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(StatCard), findsNothing);
  });

  testWidgets('a failure shows the message and Retry', (tester) async {
    await show(
      tester,
      const OwnerDashboardState(
        view: DashboardView.failure,
        errorMessage: 'No internet connection.',
      ),
    );

    await tester.tap(find.text('Retry'));

    expect(find.text('No internet connection.'), findsOneWidget);
    verify(() => dashboard.retry()).called(1);
  });

  testWidgets('greets the owner and names the shop', (tester) async {
    await show(tester, loaded(busyDay));

    expect(find.text('Hi, Nimal'), findsOneWidget);
    expect(find.text('Kottu Corner · Today'), findsOneWidget);
  });

  testWidgets('says just Today until the shop loads', (tester) async {
    when(() => myRestaurant.state).thenReturn(const MyRestaurantState());
    await show(tester, loaded(busyDay));

    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('shows every number of the day', (tester) async {
    await show(tester, loaded(busyDay));

    expect(inCard('stat-sales', find.text('Rs. 8,400')), findsOneWidget);
    expect(inCard('stat-done', find.text('12')), findsOneWidget);
    expect(inCard('stat-new', find.text('2')), findsOneWidget);
    expect(inCard('stat-active', find.text('3')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DroppedRow),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('lists the top dishes with how many were sold', (tester) async {
    await show(tester, loaded(busyDay));

    expect(find.text(TopDishesCard.title), findsOneWidget);
    expect(find.text('Chicken Kottu'), findsOneWidget);
    expect(find.text('× 5'), findsOneWidget);
    expect(find.text('Cheese Kottu'), findsOneWidget);
    expect(find.text('× 3'), findsOneWidget);
    expect(find.text(TopDishesCard.emptyText), findsNothing);
  });

  testWidgets('a day with no orders shows zeros and a note', (tester) async {
    await show(tester, loaded(const DaySummary()));

    expect(inCard('stat-sales', find.text('Rs. 0')), findsOneWidget);
    expect(inCard('stat-done', find.text('0')), findsOneWidget);
    expect(find.text(TopDishesCard.emptyText), findsOneWidget);
  });

  testWidgets('New, Active and Done open their chips', (tester) async {
    await show(tester, loaded(busyDay));

    await tester.tap(find.byKey(const Key('stat-new')));
    await tester.tap(find.byKey(const Key('stat-active')));
    await tester.tap(find.byKey(const Key('stat-done')));

    expect(openedChips, [
      OwnerDashboardView.newChip,
      OwnerDashboardView.activeChip,
      OwnerDashboardView.doneChip,
    ]);
  });

  testWidgets('Sales has no arrow and opens nothing', (tester) async {
    await show(tester, loaded(busyDay));

    await tester.tap(find.byKey(const Key('stat-sales')));

    expect(openedChips, isEmpty);
    expect(
      inCard('stat-sales', find.byIcon(Icons.chevron_right_rounded)),
      findsNothing,
    );
    expect(
      inCard('stat-new', find.byIcon(Icons.chevron_right_rounded)),
      findsOneWidget,
    );
  });

  testWidgets('with no way to open the board, no card has an arrow',
      (tester) async {
    await show(tester, loaded(busyDay), canOpen: false);

    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets('a big sales number shows in full', (tester) async {
    await show(tester, loaded(const DaySummary(sales: 12345678)));

    expect(inCard('stat-sales', find.text('Rs. 12,345,678')), findsOneWidget);
  });

  testWidgets('big phone fonts do not overflow', (tester) async {
    await show(
      tester,
      loaded(const DaySummary(sales: 12345678, doneCount: 1234)),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Rs. 12,345,678'), findsOneWidget);
  });

  testWidgets('the numbers change live', (tester) async {
    phoneSize(tester);
    whenListen(
      dashboard,
      Stream.fromIterable([loaded(const DaySummary(newCount: 1))]),
      initialState: loaded(const DaySummary()),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(inCard('stat-new', find.text('1')), findsOneWidget);
  });
}