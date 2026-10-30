import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_repository.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:ada_rasa_foods/features/orders/domain/seen_order_repository.dart';
import 'package:ada_rasa_foods/features/orders/presentation/my_orders_cubit.dart';
import 'package:ada_rasa_foods/features/orders/presentation/my_orders_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOrderRepository extends Mock implements OrderRepository {}

class MockSeenOrderRepository extends Mock implements SeenOrderRepository {}

FoodOrder order(String id, OrderStatus status) {
  return FoodOrder(
    id: id,
    customerId: 'u1',
    customerName: 'Nimal',
    restaurantId: 'r1',
    restaurantName: 'Kottu Corner',
    restaurantAddress: 'Colombo',
    items: const [],
    total: 1200,
    paymentMethod: PaymentMethod.cash,
    paymentStatus: PaymentStatus.pending,
    status: status,
  );
}

// Lets the seen ids load and stream events reach the cubit.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late MockOrderRepository orders;
  late MockSeenOrderRepository seen;
  late StreamController<List<FoodOrder>> u1Orders;
  late StreamController<List<FoodOrder>> u2Orders;
  late MyOrdersCubit cubit;

  final placed = order('o3', OrderStatus.placed);
  final preparing = order('o2', OrderStatus.preparing);
  final rejected = order('o1', OrderStatus.rejected);
  final completed = order('o0', OrderStatus.completed);

  setUp(() {
    orders = MockOrderRepository();
    seen = MockSeenOrderRepository();
    u1Orders = StreamController<List<FoodOrder>>.broadcast();
    u2Orders = StreamController<List<FoodOrder>>.broadcast();

    when(() => orders.watchCustomerOrders('u1'))
        .thenAnswer((_) => u1Orders.stream);
    when(() => orders.watchCustomerOrders('u2'))
        .thenAnswer((_) => u2Orders.stream);
    when(() => seen.loadSeen(any())).thenAnswer((_) async => <String>{});
    when(() => seen.markSeen(any(), any())).thenAnswer((_) async {});

    cubit = MyOrdersCubit(orders, seen);
  });

  tearDown(() async {
    await cubit.close();
    await u1Orders.close();
    await u2Orders.close();
  });

  Future<void> startWith(List<FoodOrder> list, {String user = 'u1'}) async {
    await cubit.start(user);
    await settle();
    (user == 'u1' ? u1Orders : u2Orders).add(list);
    await settle();
  }

  test('starts loading with no orders', () {
    expect(cubit.state, const MyOrdersState());
  });

  test('shows the orders when they arrive', () async {
    await startWith([placed, rejected]);

    expect(cubit.state.status, MyOrdersStatus.loaded);
    expect(cubit.state.orders, [placed, rejected]);
  });

  test('active orders are the ones not finished yet', () async {
    await startWith([placed, preparing, rejected, completed]);

    expect(cubit.state.activeOrders, [placed, preparing]);
  });

  test('no orders gives no active orders and no rejected one', () async {
    await startWith([]);

    expect(cubit.state.status, MyOrdersStatus.loaded);
    expect(cubit.state.activeOrders, isEmpty);
    expect(cubit.state.unseenRejected, isNull);
  });

  test('shows a rejected order that was not opened yet', () async {
    await startWith([placed, rejected, completed]);

    expect(cubit.state.unseenRejected, rejected);
  });

  test('a rejected order opened before stays hidden', () async {
    when(() => seen.loadSeen('u1')).thenAnswer((_) async => {'o1'});

    await startWith([placed, rejected]);

    expect(cubit.state.unseenRejected, isNull);
  });

  test('markSeen hides the rejected order and saves it', () async {
    await startWith([rejected]);

    await cubit.markSeen(rejected);

    expect(cubit.state.unseenRejected, isNull);
    verify(() => seen.markSeen('u1', 'o1')).called(1);
  });

  test('markSeen does nothing for an order that is not rejected', () async {
    await startWith([placed]);

    await cubit.markSeen(placed);

    expect(cubit.state.seenIds, isEmpty);
    verifyNever(() => seen.markSeen(any(), any()));
  });

  test('markSeen saves an order only once', () async {
    await startWith([rejected]);

    await cubit.markSeen(rejected);
    await cubit.markSeen(rejected);

    verify(() => seen.markSeen('u1', 'o1')).called(1);
  });

  test('a live change to rejected shows the red banner order', () async {
    await startWith([placed]);
    expect(cubit.state.unseenRejected, isNull);

    final nowRejected = order('o3', OrderStatus.rejected);
    u1Orders.add([nowRejected]);
    await settle();

    expect(cubit.state.unseenRejected, nowRejected);
    expect(cubit.state.activeOrders, isEmpty);
  });

  test('starting again for the same user does not load twice', () async {
    await startWith([placed]);

    await cubit.start('u1');
    await settle();

    verify(() => orders.watchCustomerOrders('u1')).called(1);
    expect(cubit.state.orders, [placed]);
  });

  test('a different user gets their own orders', () async {
    await startWith([placed]);

    final theirs = order('x1', OrderStatus.preparing);
    await startWith([theirs], user: 'u2');

    expect(cubit.state.orders, [theirs]);
    verify(() => seen.loadSeen('u2')).called(1);
  });

  test('shows the error message when loading fails', () async {
    await cubit.start('u1');
    await settle();
    u1Orders.addError(
      const DataFailure('No internet connection. Please try again.'),
    );
    await settle();

    expect(cubit.state.status, MyOrdersStatus.failure);
    expect(
      cubit.state.errorMessage,
      'No internet connection. Please try again.',
    );
  });

  test('Retry loads the orders again after an error', () async {
    await cubit.start('u1');
    await settle();
    u1Orders.addError(const DataFailure('No internet connection.'));
    await settle();

    cubit.retry();
    await settle();
    u1Orders.add([placed]);
    await settle();

    expect(cubit.state.status, MyOrdersStatus.loaded);
    expect(cubit.state.orders, [placed]);
    verify(() => orders.watchCustomerOrders('u1')).called(2);
  });
}