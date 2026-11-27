import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/features/auth/domain/app_user.dart';
import 'package:ada_rasa_foods/features/auth/domain/user_role.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
import 'package:ada_rasa_foods/features/dashboard/domain/dash_period.dart';
import 'package:ada_rasa_foods/features/dashboard/domain/day_summary.dart';
import 'package:ada_rasa_foods/features/dashboard/presentation/dashboard_cards.dart';
import 'package:ada_rasa_foods/features/dashboard/presentation/owner_dashboard_cubit.dart';
import 'package:ada_rasa_foods/features/dashboard/presentation/owner_dashboard_page.dart';
import 'package:ada_rasa_foods/features/dashboard/presentation/owner_dashboard_state.dart';
import 'package:ada_rasa_foods/features/dashboard/presentation/sales_chart.dart';
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
);

// A Friday.
final friday = DateTime(2026, 11, 27);

const busyDay = DaySummary(
  sales: 8400,
  doneCount: 12,
  newCount: 2,
  activeCount: 3,
  droppedCount: 1,
  topDishes: [
    TopDish(dishId: 'd1', name: 'Chicken Kottu', quantity: 6),
    TopDish(dishId: 'd2', name: 'Cheese Kottu', quantity: 3),
  ],
);

OwnerDashboardState loaded(
  DaySummary summary, {
  DashPeriod period = DashPeriod.today,
  List<int> weekSales = const [0, 0, 0, 0, 0, 0, 0],
}) {
  return OwnerDashboardState(
    view: DashboardView.loaded,
    period: period,
    summary: summary,
    weekSales: weekSales,
    today: friday,
  );
}

void main() {
  late MockAuthCubit authCubit;
  late MockDashboardCubit dashboard;
  late MockMyRestaurantCubit myRestaurant;
  late List<int> openedChips;

  setUpAll(() => registerFallbackValue(DashPeriod.today));

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

  Finder inKey(String key, Finder matching) {
    return find.descendant(of: find.byKey(Key(key)), matching: matching);
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  group('loading and errors', () {
    testWidgets('shows a spinner while loading', (tester) async {
      phoneSize(tester);
      when(() => dashboard.state).thenReturn(const OwnerDashboardState());
      await tester.pumpWidget(app());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(HeroCard), findsNothing);
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
  });

  group('orange card', () {
    testWidgets('greets the owner and names the shop', (tester) async {
      await show(tester, loaded(busyDay));

      expect(find.text('Hi, Nimal'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HeroCard),
          matching: find.text('Kottu Corner'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('has no shop name until the shop loads', (tester) async {
      when(() => myRestaurant.state).thenReturn(const MyRestaurantState());
      await show(tester, loaded(busyDay));

      expect(find.text('Kottu Corner'), findsNothing);
      expect(find.text('Rs. 8,400'), findsOneWidget);
    });

    testWidgets('shows sales and done', (tester) async {
      await show(tester, loaded(busyDay));

      expect(inKey('hero-sales', find.text('Rs. 8,400')), findsOneWidget);
      expect(inKey('stat-done', find.text('12')), findsOneWidget);
    });

    testWidgets('the card is orange', (tester) async {
      await show(tester, loaded(busyDay));

      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(HeroCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).color, AppTheme.brandOrange);
    });

    testWidgets('shows Today, 7 days and 30 days', (tester) async {
      await show(tester, loaded(busyDay));

      for (final period in DashPeriod.values) {
        expect(find.byKey(Key('period-${period.name}')), findsOneWidget);
        expect(find.text(period.label), findsOneWidget);
      }
    });

    testWidgets('the picked period is white, the others are not',
        (tester) async {
      await show(tester, loaded(busyDay, period: DashPeriod.week));

      Color? colorOf(DashPeriod p) =>
          tester.widget<Material>(find.byKey(Key('period-${p.name}'))).color;

      expect(colorOf(DashPeriod.week), Colors.white);
      expect(colorOf(DashPeriod.today), isNot(Colors.white));
      expect(colorOf(DashPeriod.month), isNot(Colors.white));
    });

    testWidgets('tapping a period tells the cubit', (tester) async {
      await show(tester, loaded(busyDay));

      await tester.tap(find.byKey(const Key('period-week')));
      await tester.tap(find.byKey(const Key('period-month')));

      verify(() => dashboard.pickPeriod(DashPeriod.week)).called(1);
      verify(() => dashboard.pickPeriod(DashPeriod.month)).called(1);
    });

    testWidgets('a big sales number shows in full', (tester) async {
      await show(tester, loaded(const DaySummary(sales: 12345678)));

      expect(find.text('Rs. 12,345,678'), findsOneWidget);
    });
  });

  group('chart', () {
    testWidgets('has the title and 7 bars', (tester) async {
      await show(tester, loaded(busyDay));

      expect(find.text(OwnerDashboardView.chartTitle), findsOneWidget);
      for (var i = 0; i < 7; i++) {
        expect(find.byKey(Key('bar-$i')), findsOneWidget);
      }
    });

    testWidgets('names the days, today last', (tester) async {
      await show(tester, loaded(busyDay));

      final letters = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(WeekSalesChart),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();

      // Saturday to Friday.
      expect(letters, ['S', 'S', 'M', 'T', 'W', 'T', 'F']);
    });

    testWidgets('the tallest bar is the best day', (tester) async {
      await show(
        tester,
        loaded(busyDay, weekSales: [100, 400, 0, 0, 0, 0, 200]),
      );

      double heightOf(int i) =>
          tester.getSize(find.byKey(Key('bar-$i'))).height;

      expect(heightOf(1), WeekSalesChart.barsHeight);
      expect(heightOf(6), WeekSalesChart.barsHeight / 2);
      expect(heightOf(0), WeekSalesChart.barsHeight / 4);
      expect(heightOf(2), WeekSalesChart.minBar);
    });

    testWidgets('a week with no sales shows thin bars', (tester) async {
      await show(tester, loaded(busyDay));

      for (var i = 0; i < 7; i++) {
        expect(
          tester.getSize(find.byKey(Key('bar-$i'))).height,
          WeekSalesChart.minBar,
        );
      }
    });

    testWidgets('only today is solid orange', (tester) async {
      await show(tester, loaded(busyDay));

      Color? colorOf(int i) {
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byKey(Key('bar-$i')),
            matching: find.byType(DecoratedBox),
          ),
        );
        return (box.decoration as BoxDecoration).color;
      }

      expect(colorOf(6), AppTheme.brandOrange);
      expect(colorOf(5), isNot(AppTheme.brandOrange));
    });

    testWidgets('each bar reads its day and amount', (tester) async {
      await show(
        tester,
        loaded(busyDay, weekSales: [0, 0, 0, 0, 0, 0, 1500]),
      );

      expect(find.bySemanticsLabel('Fri Rs. 1,500'), findsOneWidget);
      expect(find.bySemanticsLabel('Sat Rs. 0'), findsOneWidget);
    });
  });

  group('pills', () {
    testWidgets('show New, Active and Rejected counts', (tester) async {
      await show(tester, loaded(busyDay));

      expect(inKey('stat-new', find.text('2')), findsOneWidget);
      expect(inKey('stat-active', find.text('3')), findsOneWidget);
      expect(inKey('stat-dropped', find.text('1')), findsOneWidget);
      expect(inKey('stat-dropped', find.text('Rejected')), findsOneWidget);
    });

    testWidgets('New, Active and Done open their chips', (tester) async {
      await show(tester, loaded(busyDay));

      await scrollTo(tester, find.byKey(const Key('stat-new')));
      await tester.tap(find.byKey(const Key('stat-new')));
      await tester.tap(find.byKey(const Key('stat-active')));
      await scrollTo(tester, find.byKey(const Key('stat-done')));
      await tester.tap(find.byKey(const Key('stat-done')));

      expect(openedChips, [
        OwnerDashboardView.newChip,
        OwnerDashboardView.activeChip,
        OwnerDashboardView.doneChip,
      ]);
    });

    testWidgets('Rejected opens nothing', (tester) async {
      await show(tester, loaded(busyDay));

      await scrollTo(tester, find.byKey(const Key('stat-dropped')));
      await tester.tap(find.byKey(const Key('stat-dropped')));

      expect(openedChips, isEmpty);
    });

    testWidgets('with no way to open the board, Done has no arrow',
        (tester) async {
      await show(tester, loaded(busyDay), canOpen: false);

      expect(
        inKey('stat-done', find.byIcon(Icons.chevron_right_rounded)),
        findsNothing,
      );
    });
  });

  group('top dishes', () {
    testWidgets('shows rank, name, amount and a share bar', (tester) async {
      await show(tester, loaded(busyDay));
      await scrollTo(tester, find.text('Cheese Kottu'));

      expect(find.text(TopDishesCard.title), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('Chicken Kottu'), findsOneWidget);
      expect(find.text('× 6'), findsOneWidget);
      expect(find.text('× 3'), findsOneWidget);

      final full = tester.getSize(find.byKey(const Key('share-d1'))).width;
      final half = tester.getSize(find.byKey(const Key('share-d2'))).width;
      expect(half, closeTo(full / 2, 0.5));
    });

    testWidgets('no orders today says so', (tester) async {
      await show(tester, loaded(const DaySummary()));
      await scrollTo(tester, find.byType(TopDishesCard));

      expect(find.text('No orders yet today'), findsOneWidget);
    });

    testWidgets('no orders in 7 days says so', (tester) async {
      await show(
        tester,
        loaded(const DaySummary(), period: DashPeriod.week),
      );
      await scrollTo(tester, find.byType(TopDishesCard));

      expect(find.text('No orders in the last 7 days'), findsOneWidget);
    });
  });

  testWidgets('big phone fonts do not overflow', (tester) async {
    await show(
      tester,
      loaded(
        const DaySummary(
          sales: 12345678,
          doneCount: 1234,
          newCount: 120,
          activeCount: 340,
          droppedCount: 56,
          topDishes: [
            TopDish(
              dishId: 'd1',
              name: 'Very long dish name with cheese and egg',
              quantity: 999,
            ),
          ],
        ),
        weekSales: const [1, 2, 3, 4, 5, 6, 7],
      ),
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

    expect(inKey('stat-new', find.text('1')), findsOneWidget);
  });
}