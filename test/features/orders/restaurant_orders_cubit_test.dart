import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_repository.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:ada_rasa_foods/features/orders/presentation/restaurant_orders_cubit.dart';
import 'package:ada_rasa_foods/features/orders/presentation/restaurant_orders_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOrderRepository extends Mock implements OrderRepository {}

FoodOrder order(String id, {OrderStatus status = OrderStatus.placed}) {
  return FoodOrder(
    id: id,
    customerId: 'u1',
    customerName: 'Nimal',
    restaurantId: 'r1',
    restaurantName: 'Kottu Corner',
    restaurantAddress: '112 Galle Road, Colombo 04',
    items: const [],
    total: 2400,
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
  late StreamController<List<FoodOrder>> doneStream;

  final placed = order('abcdef111');
  final placed2 = order('xyz789222');
  final preparing = order('prep00333', status: OrderStatus.preparing);
  final completed = order('done00444', status: OrderStatus.completed);

  setUpAll(() {
    registerFallbackValue(order('fallback'));
    registerFallbackValue(OrderStatus.placed);
  });

  setUp(() {
    orders = MockOrderRepository();
    openStream = StreamController<List<FoodOrder>>.broadcast();
    doneStream = StreamController<List<FoodOrder>>.broadcast();
    when(() => orders.watchRestaurantOpenOrders('r1'))
        .thenAnswer((_) => openStream.stream);
    when(() => orders.watchRestaurantDoneOrders('r1'))
        .thenAnswer((_) => doneStream.stream);
    when(() => orders.moveOrder(any(), any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    await openStream.close();
    await doneStream.close();
  });

  RestaurantOrdersCubit build() => RestaurantOrdersCubit(orders);

  test('starts loading', () {
    expect(build().state, const RestaurantOrdersState());
  });

  test('splits open orders into New and Active', () async {
    final cubit = build();
    await cubit.start('r1');

    openStream.add([placed, preparing]);
    await settle();

    expect(cubit.state.view, BoardView.loaded);
    expect(cubit.state.newOrders, [placed]);
    expect(cubit.state.activeOrders, [preparing]);
    await cubit.close();
  });

  test('shows done orders when they load', () async {
    final cubit = build();
    await cubit.start('r1');

    doneStream.add([completed]);
    await settle();

    expect(cubit.state.done, [completed]);
    expect(cubit.state.doneLoaded, isTrue);
    await cubit.close();
  });

  test('the first load gives no new order alert', () async {
    final cubit = build();
    await cubit.start('r1');

    openStream.add([placed]);
    await settle();

    expect(cubit.state.newOrderAlertId, 0);
    expect(cubit.state.newOrderNumber, isNull);
    await cubit.close();
  });

  test('a new order that arrives later gives an alert', () async {
    final cubit = build();
    await cubit.start('r1');
    openStream.add([placed]);
    await settle();

    openStream.add([placed, placed2]);
    await settle();

    expect(cubit.state.newOrderAlertId, 1);
    expect(cubit.state.newOrderNumber, 'XYZ789');
    await cubit.close();
  });

  test('an accepted order gives no alert', () async {
    final cubit = build();
    await cubit.start('r1');
    openStream.add([placed]);
    await settle();

    openStream.add([order('abcdef111', status: OrderStatus.accepted)]);
    await settle();

    expect(cubit.state.newOrderAlertId, 0);
    expect(cubit.state.activeOrders, hasLength(1));
    await cubit.close();
  });

  test('the same new order twice gives only one alert', () async {
    final cubit = build();
    await cubit.start('r1');
    openStream.add([]);
    await settle();

    openStream.add([placed]);
    await settle();
    openStream.add([placed]);
    await settle();

    expect(cubit.state.newOrderAlertId, 1);
    await cubit.close();
  });

  blocTest<RestaurantOrdersCubit, RestaurantOrdersState>(
    'a load error shows the message',
    build: build,
    act: (cubit) async {
      await cubit.start('r1');
      openStream.addError(const DataFailure('No internet connection.'));
      await settle();
    },
    expect: () => [
      const RestaurantOrdersState(),
      const RestaurantOrdersState(
        view: BoardView.failure,
        errorMessage: 'No internet connection.',
      ),
    ],
  );

  test('retry starts watching again', () async {
    final cubit = build();
    await cubit.start('r1');
    openStream.addError(const DataFailure('No internet connection.'));
    await settle();

    cubit.retry();
    await settle();
    openStream.add([placed]);
    await settle();

    expect(cubit.state.view, BoardView.loaded);
    verify(() => orders.watchRestaurantOpenOrders('r1')).called(2);
    await cubit.close();
  });

  test('move saves the step and shows a message', () async {
    final cubit = build();
    await cubit.start('r1');
    openStream.add([placed]);
    await settle();

    await cubit.move(placed, OrderStatus.accepted);

    verify(() => orders.moveOrder(placed, OrderStatus.accepted)).called(1);
    expect(cubit.state.notice, 'Order #ABCDEF is now accepted.');
    expect(cubit.state.noticeId, 1);
    expect(cubit.state.busyIds, isEmpty);
    await cubit.close();
  });

  test('the order is busy while it saves', () async {
    final save = Completer<void>();
    when(() => orders.moveOrder(any(), any()))
        .thenAnswer((_) => save.future);
    final cubit = build();

    final moving = cubit.move(placed, OrderStatus.accepted);
    await settle();

    expect(cubit.state.isBusy(placed), isTrue);
    save.complete();
    await moving;
    expect(cubit.state.isBusy(placed), isFalse);
    await cubit.close();
  });

  test('a second tap while saving does nothing', () async {
    final save = Completer<void>();
    when(() => orders.moveOrder(any(), any()))
        .thenAnswer((_) => save.future);
    final cubit = build();

    final first = cubit.move(placed, OrderStatus.accepted);
    await cubit.move(placed, OrderStatus.accepted);
    save.complete();
    await first;

    verify(() => orders.moveOrder(any(), any())).called(1);
    await cubit.close();
  });

  test('a refused step shows the reason', () async {
    when(() => orders.moveOrder(any(), any())).thenThrow(
      const DataFailure('The customer cancelled this order.'),
    );
    final cubit = build();

    await cubit.move(placed, OrderStatus.accepted);

    expect(cubit.state.notice, 'The customer cancelled this order.');
    expect(cubit.state.busyIds, isEmpty);
    await cubit.close();
  });

  test('ready shows the pickup label in the message', () async {
    final cubit = build();

    await cubit.move(preparing, OrderStatus.ready);

    expect(cubit.state.notice, 'Order #PREP00 is now ready for pickup.');
    await cubit.close();
  });
}