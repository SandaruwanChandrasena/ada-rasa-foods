import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_repository.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:ada_rasa_foods/features/orders/presentation/order_status_cubit.dart';
import 'package:ada_rasa_foods/features/orders/presentation/order_status_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOrderRepository extends Mock implements OrderRepository {}

FoodOrder order({OrderStatus status = OrderStatus.placed}) {
  return FoodOrder(
    id: 'o1',
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
  late StreamController<FoodOrder?> orderStream;

  final placed = order();
  final accepted = order(status: OrderStatus.accepted);

  setUpAll(() => registerFallbackValue(order()));

  setUp(() {
    orders = MockOrderRepository();
    orderStream = StreamController<FoodOrder?>.broadcast();
    when(() => orders.watchOrder('o1')).thenAnswer((_) => orderStream.stream);
    when(() => orders.cancelOrder(any())).thenAnswer((_) async {});
  });

  tearDown(() => orderStream.close());

  OrderStatusCubit build() => OrderStatusCubit(orders);

  test('starts loading', () {
    expect(build().state, const OrderStatusState());
  });

  blocTest<OrderStatusCubit, OrderStatusState>(
    'shows the order when it arrives',
    build: build,
    act: (cubit) async {
      cubit.start('o1');
      orderStream.add(placed);
      await settle();
    },
    expect: () => [
      const OrderStatusState(),
      OrderStatusState(view: OrderView.loaded, order: placed),
    ],
  );

  blocTest<OrderStatusCubit, OrderStatusState>(
    'shows a live change when the restaurant accepts',
    build: build,
    act: (cubit) async {
      cubit.start('o1');
      orderStream.add(placed);
      await settle();
      orderStream.add(accepted);
      await settle();
    },
    // Skips the first loading state.
    skip: 1,
    expect: () => [
      OrderStatusState(view: OrderView.loaded, order: placed),
      OrderStatusState(view: OrderView.loaded, order: accepted),
    ],
  );

  blocTest<OrderStatusCubit, OrderStatusState>(
    'shows not found when the order does not exist',
    build: build,
    act: (cubit) async {
      cubit.start('o1');
      orderStream.add(null);
      await settle();
    },
    skip: 1,
    expect: () => const [OrderStatusState(view: OrderView.notFound)],
  );

  blocTest<OrderStatusCubit, OrderStatusState>(
    'shows the error message when loading fails',
    build: build,
    act: (cubit) async {
      cubit.start('o1');
      orderStream.addError(
        const DataFailure('No internet connection. Please try again.'),
      );
      await settle();
    },
    skip: 1,
    expect: () => const [
      OrderStatusState(
        view: OrderView.failure,
        errorMessage: 'No internet connection. Please try again.',
      ),
    ],
  );

  blocTest<OrderStatusCubit, OrderStatusState>(
    'Retry loads the order again after an error',
    build: build,
    act: (cubit) async {
      cubit.start('o1');
      orderStream.addError(const DataFailure('No internet connection.'));
      await settle();
      cubit.retry();
      orderStream.add(placed);
      await settle();
    },
    // Skips loading and the error, then checks the second load.
    skip: 2,
    expect: () => [
      const OrderStatusState(),
      OrderStatusState(view: OrderView.loaded, order: placed),
    ],
  );

  blocTest<OrderStatusCubit, OrderStatusState>(
    'cancel calls the repository and shows a message',
    build: build,
    act: (cubit) async {
      cubit.start('o1');
      orderStream.add(placed);
      await settle();
      await cubit.cancel();
    },
    skip: 2,
    expect: () => [
      OrderStatusState(
        view: OrderView.loaded,
        order: placed,
        isCancelling: true,
      ),
      OrderStatusState(
        view: OrderView.loaded,
        order: placed,
        notice: 'Your order is cancelled.',
        noticeId: 1,
      ),
    ],
    verify: (_) => verify(() => orders.cancelOrder(placed)).called(1),
  );

  blocTest<OrderStatusCubit, OrderStatusState>(
    'cancel shows the reason when it fails',
    setUp: () => when(() => orders.cancelOrder(any())).thenThrow(
      const DataFailure(
        'This order is accepted now. It can no longer be cancelled.',
      ),
    ),
    build: build,
    act: (cubit) async {
      cubit.start('o1');
      orderStream.add(placed);
      await settle();
      await cubit.cancel();
    },
    skip: 3,
    expect: () => [
      OrderStatusState(
        view: OrderView.loaded,
        order: placed,
        notice: 'This order is accepted now. It can no longer be cancelled.',
        noticeId: 1,
      ),
    ],
  );

  blocTest<OrderStatusCubit, OrderStatusState>(
    'cancel does nothing when the order is already accepted',
    build: build,
    act: (cubit) async {
      cubit.start('o1');
      orderStream.add(accepted);
      await settle();
      await cubit.cancel();
    },
    skip: 2,
    expect: () => const <OrderStatusState>[],
    verify: (_) => verifyNever(() => orders.cancelOrder(any())),
  );

  blocTest<OrderStatusCubit, OrderStatusState>(
    'a fast second Cancel tap cancels only once',
    build: build,
    act: (cubit) async {
      cubit.start('o1');
      orderStream.add(placed);
      await settle();
      final first = cubit.cancel();
      await cubit.cancel();
      await first;
    },
    verify: (_) => verify(() => orders.cancelOrder(any())).called(1),
  );
}