import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/dashboard/domain/day_summary.dart';
import 'package:ada_rasa_foods/features/dashboard/presentation/owner_dashboard_cubit.dart';
import 'package:ada_rasa_foods/features/dashboard/presentation/owner_dashboard_state.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_repository.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOrderRepository extends Mock implements OrderRepository {}

FoodOrder order(OrderStatus status, {int total = 1000}) {
  return FoodOrder(
    customerId: 'u1',
    customerName: 'Nimal',
    restaurantId: 'r1',
    restaurantName: 'Kottu Corner',
    restaurantAddress: '112 Galle Road',
    items: const [],
    total: total,
    paymentMethod: PaymentMethod.cash,
    paymentStatus: PaymentStatus.pending,
    status: status,
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
    now = DateTime(2026, 11, 27, 10, 30);
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

  test('starts loading', () {
    expect(build().state, const OwnerDashboardState());
  });

  test('stays loading until both lists arrive', () async {
    final cubit = build();
    await cubit.start('r1');

    openStream.add([order(OrderStatus.placed)]);
    await settle();

    expect(cubit.state.view, DashboardView.loading);
  });

  test('shows the summary of both lists', () async {
    final cubit = build();
    await cubit.start('r1');

    openStream.add([order(OrderStatus.placed), order(OrderStatus.ready)]);
    endedStream.add([
      order(OrderStatus.completed, total: 1500),
      order(OrderStatus.rejected),
    ]);
    await settle();

    expect(
      cubit.state,
      const OwnerDashboardState(
        view: DashboardView.loaded,
        summary: DaySummary(
          sales: 1500,
          doneCount: 1,
          newCount: 1,
          activeCount: 1,
          droppedCount: 1,
        ),
      ),
    );
  });

  test('a new order raises the New count live', () async {
    final cubit = build();
    await cubit.start('r1');
    openStream.add([]);
    endedStream.add([]);
    await settle();

    openStream.add([order(OrderStatus.placed)]);
    await settle();

    expect(cubit.state.summary.newCount, 1);
  });

  test('asks for ended orders from midnight today', () async {
    final cubit = build();
    await cubit.start('r1');

    verify(
      () => orders.watchRestaurantEndedSince('r1', DateTime(2026, 11, 27)),
    ).called(1);
  });

  test('a new day asks again from the new midnight', () async {
    final cubit = build();
    await cubit.start('r1');
    openStream.add([]);
    endedStream.add([order(OrderStatus.completed, total: 900)]);
    await settle();
    expect(cubit.state.summary.sales, 900);

    now = DateTime(2026, 11, 28, 0, 0, 1);
    await cubit.newDay();
    endedStream.add([]);
    await settle();

    verify(
      () => orders.watchRestaurantEndedSince('r1', DateTime(2026, 11, 28)),
    ).called(1);
    expect(cubit.state.summary.sales, 0);
  });

  test('a new day keeps the open orders', () async {
    final cubit = build();
    await cubit.start('r1');
    openStream.add([order(OrderStatus.preparing)]);
    endedStream.add([]);
    await settle();

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

  test('retry starts watching again', () async {
    final cubit = build();
    await cubit.start('r1');
    openStream.addError(Exception('boom'));
    await settle();

    cubit.retry();
    await settle();
    openStream.add([]);
    endedStream.add([]);
    await settle();

    verify(() => orders.watchRestaurantOpenOrders('r1')).called(2);
    expect(cubit.state.view, DashboardView.loaded);
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