import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/dashboard/domain/dash_period.dart';
import 'package:ada_rasa_foods/features/dashboard/domain/day_summary.dart';
import 'package:ada_rasa_foods/features/dashboard/presentation/owner_dashboard_cubit.dart';
import 'package:ada_rasa_foods/features/dashboard/presentation/owner_dashboard_state.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_item.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_repository.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOrderRepository extends Mock implements OrderRepository {}

final today = DateTime(2026, 11, 27);

FoodOrder order(
  OrderStatus status, {
  int total = 1000,
  DateTime? placedAt,
  List<OrderItem> items = const [],
}) {
  return FoodOrder(
    customerId: 'u1',
    customerName: 'Nimal',
    restaurantId: 'r1',
    restaurantName: 'Kottu Corner',
    restaurantAddress: '112 Galle Road',
    items: items,
    total: total,
    paymentMethod: PaymentMethod.cash,
    paymentStatus: PaymentStatus.pending,
    status: status,
    placedAt: placedAt ?? today.add(const Duration(hours: 9)),
  );
}

FoodOrder soldDaysAgo(int days, int total) {
  return order(
    OrderStatus.completed,
    total: total,
    placedAt: DateTime(today.year, today.month, today.day - days, 12),
  );
}

// Lets stream events reach the cubit.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late MockOrderRepository orders;
  late StreamController<List<FoodOrder>> openStream;
  late StreamController<List<FoodOrder>> endedStream;
  late DateTime now;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    orders = MockOrderRepository();
    openStream = StreamController<List<FoodOrder>>.broadcast();
    endedStream = StreamController<List<FoodOrder>>.broadcast();
    now = today.add(const Duration(hours: 10, minutes: 30));
    when(() => orders.watchRestaurantOpenOrders('r1'))
        .thenAnswer((_) => openStream.stream);
    when(() => orders.watchRestaurantEndedSince('r1', any()))
        .thenAnswer((_) => endedStream.stream);
  });

  tearDown(() async {
    await openStream.close();
    await endedStream.close();
  });

  OwnerDashboardCubit build() {
    final cubit = OwnerDashboardCubit(orders, now: () => now);
    addTearDown(cubit.close);
    return cubit;
  }

  // Starts the cubit and sends both lists.
  Future<OwnerDashboardCubit> loaded({
    List<FoodOrder> open = const [],
    List<FoodOrder> ended = const [],
  }) async {
    final cubit = build();
    await cubit.start('r1');
    openStream.add(open);
    endedStream.add(ended);
    await settle();
    return cubit;
  }

  test('starts loading on Today', () {
    expect(build().state, const OwnerDashboardState());
    expect(build().state.period, DashPeriod.today);
  });

  test('stays loading until both lists arrive', () async {
    final cubit = build();
    await cubit.start('r1');

    openStream.add([order(OrderStatus.placed)]);
    await settle();

    expect(cubit.state.view, DashboardView.loading);
  });

  test('shows the numbers of today', () async {
    final cubit = await loaded(
      open: [order(OrderStatus.placed), order(OrderStatus.ready)],
      ended: [
        order(OrderStatus.completed, total: 1500),
        order(OrderStatus.rejected),
      ],
    );

    expect(cubit.state.view, DashboardView.loaded);
    expect(
      cubit.state.summary,
      const DaySummary(
        sales: 1500,
        doneCount: 1,
        newCount: 1,
        activeCount: 1,
        droppedCount: 1,
      ),
    );
  });

  test('a new order raises the New count live', () async {
    final cubit = await loaded();

    openStream.add([order(OrderStatus.placed)]);
    await settle();

    expect(cubit.state.summary.newCount, 1);
  });

  test('loads ended orders of the last 30 days once', () async {
    await loaded();

    verify(
      () => orders.watchRestaurantEndedSince('r1', DateTime(2026, 10, 29)),
    ).called(1);
  });

  test('Today leaves out yesterday, 7 days has it', () async {
    final cubit = await loaded(
      ended: [soldDaysAgo(0, 300), soldDaysAgo(1, 200)],
    );
    expect(cubit.state.summary.sales, 300);

    cubit.pickPeriod(DashPeriod.week);

    expect(cubit.state.period, DashPeriod.week);
    expect(cubit.state.summary.sales, 500);
    expect(cubit.state.summary.doneCount, 2);
  });

  test('30 days has a sale from 20 days ago, 7 days does not', () async {
    final cubit = await loaded(ended: [soldDaysAgo(20, 900)]);

    cubit.pickPeriod(DashPeriod.week);
    expect(cubit.state.summary.sales, 0);

    cubit.pickPeriod(DashPeriod.month);
    expect(cubit.state.summary.sales, 900);
  });

  test('7 days shows up to 5 top dishes, Today 3', () async {
    final cubit = await loaded(
      ended: [
        order(
          OrderStatus.completed,
          items: [
            for (final id in ['a', 'b', 'c', 'd', 'e', 'f'])
              OrderItem(dishId: id, name: id, price: 100, quantity: 1),
          ],
        ),
      ],
    );
    expect(cubit.state.summary.topDishes, hasLength(3));

    cubit.pickPeriod(DashPeriod.week);

    expect(cubit.state.summary.topDishes, hasLength(5));
  });

  test('switching the period makes no new read', () async {
    final cubit = await loaded();

    cubit.pickPeriod(DashPeriod.week);
    cubit.pickPeriod(DashPeriod.month);
    cubit.pickPeriod(DashPeriod.today);

    verify(() => orders.watchRestaurantEndedSince('r1', any())).called(1);
    verify(() => orders.watchRestaurantOpenOrders('r1')).called(1);
  });

  test('the chart has the last 7 days, today last', () async {
    final cubit = await loaded(
      ended: [soldDaysAgo(0, 100), soldDaysAgo(6, 600), soldDaysAgo(9, 1)],
    );

    expect(cubit.state.weekSales, [600, 0, 0, 0, 0, 0, 100]);
    expect(cubit.state.today, today);
  });

  test('a period picked while loading stays after loading', () async {
    final cubit = build();
    await cubit.start('r1');

    cubit.pickPeriod(DashPeriod.month);
    expect(cubit.state.view, DashboardView.loading);
    expect(cubit.state.period, DashPeriod.month);

    openStream.add([]);
    endedStream.add([soldDaysAgo(20, 900)]);
    await settle();

    expect(cubit.state.period, DashPeriod.month);
    expect(cubit.state.summary.sales, 900);
  });

  test('a new day moves Today on, even before new data', () async {
    final cubit = await loaded(ended: [soldDaysAgo(0, 900)]);
    expect(cubit.state.summary.sales, 900);

    now = DateTime(2026, 11, 28, 0, 0, 1);
    await cubit.newDay();

    expect(cubit.state.summary.sales, 0);
    expect(cubit.state.weekSales, [0, 0, 0, 0, 0, 900, 0]);
    expect(cubit.state.today, DateTime(2026, 11, 28));
  });

  test('a new day asks again from the new 30 day start', () async {
    final cubit = await loaded();

    now = DateTime(2026, 11, 28, 0, 0, 1);
    await cubit.newDay();

    verify(
      () => orders.watchRestaurantEndedSince('r1', DateTime(2026, 10, 30)),
    ).called(1);
  });

  test('a new day keeps the open orders', () async {
    final cubit = await loaded(open: [order(OrderStatus.preparing)]);

    now = DateTime(2026, 11, 28, 0, 0, 1);
    await cubit.newDay();
    endedStream.add([]);
    await settle();

    expect(cubit.state.summary.activeCount, 1);
  });

  test('shows the error message when loading fails', () async {
    final cubit = build();
    await cubit.start('r1');

    endedStream.addError(const DataFailure('No internet connection.'));
    await settle();

    expect(
      cubit.state,
      const OwnerDashboardState(
        view: DashboardView.failure,
        errorMessage: 'No internet connection.',
      ),
    );
  });

  test('an unknown error shows a general message', () async {
    final cubit = build();
    await cubit.start('r1');

    openStream.addError(Exception('boom'));
    await settle();

    expect(
      cubit.state.errorMessage,
      'Something went wrong. Please try again.',
    );
  });

  test('retry starts watching again and keeps the period', () async {
    final cubit = build();
    await cubit.start('r1');
    cubit.pickPeriod(DashPeriod.week);
    openStream.addError(Exception('boom'));
    await settle();

    cubit.retry();
    await settle();
    openStream.add([]);
    endedStream.add([]);
    await settle();

    verify(() => orders.watchRestaurantOpenOrders('r1')).called(2);
    expect(cubit.state.view, DashboardView.loaded);
    expect(cubit.state.period, DashPeriod.week);
  });

  test('close stops both streams', () async {
    final cubit = OwnerDashboardCubit(orders, now: () => now);
    await cubit.start('r1');
    expect(openStream.hasListener, isTrue);

    await cubit.close();

    expect(openStream.hasListener, isFalse);
    expect(endedStream.hasListener, isFalse);
  });

  group('untilMidnight', () {
    test('one minute before midnight', () {
      expect(
        OwnerDashboardCubit.untilMidnight(DateTime(2026, 11, 27, 23, 59)),
        const Duration(minutes: 1, seconds: 1),
      );
    });

    test('works on the last day of the month', () {
      expect(
        OwnerDashboardCubit.untilMidnight(DateTime(2026, 11, 30, 22)),
        const Duration(hours: 2, seconds: 1),
      );
    });
  });
}