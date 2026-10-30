import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/auth/domain/app_user.dart';
import 'package:ada_rasa_foods/features/auth/domain/user_role.dart';
import 'package:ada_rasa_foods/features/cart/domain/cart.dart';
import 'package:ada_rasa_foods/features/cart/domain/cart_item.dart';
import 'package:ada_rasa_foods/features/cart/presentation/cart_state.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_repository.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:ada_rasa_foods/features/orders/presentation/checkout_cubit.dart';
import 'package:ada_rasa_foods/features/orders/presentation/checkout_state.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOrderRepository extends Mock implements OrderRepository {}

class MockRestaurantRepository extends Mock implements RestaurantRepository {}

Restaurant restaurant({bool isOpen = true, bool isActive = true}) {
  return Restaurant(
    id: 'r1',
    name: 'Kottu Corner',
    cuisine: 'Sri Lankan',
    ownerId: 'owner_r1',
    address: '112 Galle Road, Colombo 04',
    latitude: 6.9,
    longitude: 79.8,
    isOpen: isOpen,
    isActive: isActive,
  );
}

const user = AppUser(
  uid: 'u1',
  name: 'Nimal',
  email: 'nimal@test.com',
  role: UserRole.customer,
);

final cart = Cart(
  restaurantId: 'r1',
  restaurantName: 'Kottu Corner',
  items: const [
    CartItem(dishId: 'd1', name: 'Chicken Kottu', price: 1200, quantity: 2),
  ],
  updatedAt: DateTime(2026, 10, 30, 10),
);

final openCart = CartState(
  userId: 'u1',
  cart: cart,
  restaurantStatus: CartRestaurantStatus.open,
);

const placing = CheckoutState(status: CheckoutStatus.placing);

void main() {
  late MockOrderRepository orders;
  late MockRestaurantRepository restaurants;

  setUpAll(() {
    registerFallbackValue(
      const FoodOrder(
        customerId: '',
        customerName: '',
        restaurantId: '',
        restaurantName: '',
        restaurantAddress: '',
        items: [],
        total: 0,
        paymentMethod: PaymentMethod.cash,
        paymentStatus: PaymentStatus.pending,
      ),
    );
  });

  setUp(() {
    orders = MockOrderRepository();
    restaurants = MockRestaurantRepository();

    when(() => restaurants.watchRestaurant('r1'))
        .thenAnswer((_) => Stream.value(restaurant()));
    when(() => orders.placeOrder(any())).thenAnswer((_) async => 'o1');
  });

  CheckoutCubit build() => CheckoutCubit(orders, restaurants);

  test('starts ready', () {
    expect(build().state, const CheckoutState());
  });

  blocTest<CheckoutCubit, CheckoutState>(
    'places a cash order and gives the new order id',
    build: build,
    act: (cubit) => cubit.placeOrder(user: user, cart: openCart),
    expect: () => const [
      placing,
      CheckoutState(status: CheckoutStatus.placed, orderId: 'o1'),
    ],
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'the saved order has the customer, address, dishes, and cash',
    build: build,
    act: (cubit) => cubit.placeOrder(user: user, cart: openCart),
    verify: (_) {
      final order = verify(() => orders.placeOrder(captureAny()))
          .captured
          .single as FoodOrder;

      expect(order.customerId, 'u1');
      expect(order.customerName, 'Nimal');
      expect(order.restaurantAddress, '112 Galle Road, Colombo 04');
      expect(order.items.single.name, 'Chicken Kottu');
      expect(order.total, 2400);
      expect(order.paymentMethod, PaymentMethod.cash);
      expect(order.paymentStatus, PaymentStatus.pending);
      expect(order.status, OrderStatus.placed);
    },
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'fails and saves nothing when the cart cannot be ordered',
    build: build,
    act: (cubit) => cubit.placeOrder(
      user: user,
      cart: openCart.copyWith(
        restaurantStatus: CartRestaurantStatus.closed,
      ),
    ),
    expect: () => const [
      CheckoutState(
        status: CheckoutStatus.failure,
        errorMessage: 'Your cart cannot be ordered right now.',
      ),
    ],
    verify: (_) => verifyNever(() => orders.placeOrder(any())),
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'fails when the restaurant closed a moment ago',
    setUp: () => when(() => restaurants.watchRestaurant('r1'))
        .thenAnswer((_) => Stream.value(restaurant(isOpen: false))),
    build: build,
    act: (cubit) => cubit.placeOrder(user: user, cart: openCart),
    expect: () => const [
      placing,
      CheckoutState(
        status: CheckoutStatus.failure,
        errorMessage: 'Kottu Corner is not taking orders now.',
      ),
    ],
    verify: (_) => verifyNever(() => orders.placeOrder(any())),
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'fails when the restaurant no longer exists',
    setUp: () => when(() => restaurants.watchRestaurant('r1'))
        .thenAnswer((_) => Stream.value(null)),
    build: build,
    act: (cubit) => cubit.placeOrder(user: user, cart: openCart),
    expect: () => const [
      placing,
      CheckoutState(
        status: CheckoutStatus.failure,
        errorMessage: 'Kottu Corner is not taking orders now.',
      ),
    ],
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'shows the error message when saving fails',
    setUp: () => when(() => orders.placeOrder(any())).thenThrow(
      const DataFailure('No internet connection. Please try again.'),
    ),
    build: build,
    act: (cubit) => cubit.placeOrder(user: user, cart: openCart),
    expect: () => const [
      placing,
      CheckoutState(
        status: CheckoutStatus.failure,
        errorMessage: 'No internet connection. Please try again.',
      ),
    ],
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'can try again after a failure',
    setUp: () {
      var calls = 0;
      when(() => orders.placeOrder(any())).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw const DataFailure('No internet connection.');
        return 'o1';
      });
    },
    build: build,
    act: (cubit) async {
      await cubit.placeOrder(user: user, cart: openCart);
      await cubit.placeOrder(user: user, cart: openCart);
    },
    expect: () => const [
      placing,
      CheckoutState(
        status: CheckoutStatus.failure,
        errorMessage: 'No internet connection.',
      ),
      placing,
      CheckoutState(status: CheckoutStatus.placed, orderId: 'o1'),
    ],
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'a fast second tap places only one order',
    build: build,
    act: (cubit) async {
      final first = cubit.placeOrder(user: user, cart: openCart);
      await cubit.placeOrder(user: user, cart: openCart);
      await first;
    },
    verify: (_) => verify(() => orders.placeOrder(any())).called(1),
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'a tap after the order is placed does nothing',
    build: build,
    act: (cubit) async {
      await cubit.placeOrder(user: user, cart: openCart);
      await cubit.placeOrder(user: user, cart: openCart);
    },
    expect: () => const [
      placing,
      CheckoutState(status: CheckoutStatus.placed, orderId: 'o1'),
    ],
    verify: (_) => verify(() => orders.placeOrder(any())).called(1),
  );
}