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
import 'package:ada_rasa_foods/features/payments/domain/card_brand.dart';
import 'package:ada_rasa_foods/features/payments/domain/payment_card.dart';
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
  phone: '0712345678',
  role: UserRole.customer,
);

const noPhoneUser = AppUser(
  uid: 'u1',
  name: 'Nimal',
  email: 'nimal@test.com',
  role: UserRole.customer,
);

const phoneNeeded = CheckoutState(
  status: CheckoutStatus.failure,
  errorMessage: CheckoutCubit.phoneNeededMessage,
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

const visa = PaymentCard(
  id: 'c1',
  brand: CardBrand.visa,
  last4: '4242',
  holderName: 'NIMAL PERERA',
  expMonth: 8,
  expYear: 2030,
);

const master = PaymentCard(
  id: 'c2',
  brand: CardBrand.mastercard,
  last4: '4444',
  holderName: 'NIMAL PERERA',
  expMonth: 5,
  expYear: 2029,
);

const failing = PaymentCard(
  id: 'c3',
  brand: CardBrand.visa,
  last4: '0002',
  holderName: 'NIMAL PERERA',
  expMonth: 8,
  expYear: 2030,
);

FoodOrder savedOrder(MockOrderRepository orders) {
  return verify(() => orders.placeOrder(captureAny())).captured.single
      as FoodOrder;
}

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
      expect(order.customerPhone, '0712345678');
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

  blocTest<CheckoutCubit, CheckoutState>(
    'a cash order has no card details',
    build: build,
    act: (cubit) => cubit.placeOrder(user: user, cart: openCart),
    verify: (_) {
      final order = savedOrder(orders);
      expect(order.cardBrand, '');
      expect(order.cardLast4, '');
    },
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'places a card order and gives the new order id',
    build: build,
    act: (cubit) =>
        cubit.placeOrder(user: user, cart: openCart, card: visa),
    expect: () => const [
      placing,
      CheckoutState(status: CheckoutStatus.placed, orderId: 'o1'),
    ],
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'a card order is saved as paid, with the card type and last 4',
    build: build,
    act: (cubit) =>
        cubit.placeOrder(user: user, cart: openCart, card: visa),
    verify: (_) {
      final order = savedOrder(orders);
      expect(order.paymentMethod, PaymentMethod.card);
      expect(order.paymentStatus, PaymentStatus.paid);
      expect(order.cardBrand, 'visa');
      expect(order.cardLast4, '4242');
      expect(order.status, OrderStatus.placed);
      expect(order.total, 2400);
    },
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'a Mastercard order saves "mastercard"',
    build: build,
    act: (cubit) =>
        cubit.placeOrder(user: user, cart: openCart, card: master),
    verify: (_) {
      final order = savedOrder(orders);
      expect(order.cardBrand, 'mastercard');
      expect(order.cardLast4, '4444');
    },
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'the card ending 0002 is never saved',
    build: build,
    act: (cubit) =>
        cubit.placeOrder(user: user, cart: openCart, card: failing),
    expect: () => const [
      CheckoutState(
        status: CheckoutStatus.failure,
        errorMessage: CheckoutCubit.declinedMessage,
      ),
    ],
    verify: (_) => verifyNever(() => orders.placeOrder(any())),
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'a card order fails when the restaurant closed a moment ago',
    setUp: () => when(() => restaurants.watchRestaurant('r1'))
        .thenAnswer((_) => Stream.value(restaurant(isOpen: false))),
    build: build,
    act: (cubit) =>
        cubit.placeOrder(user: user, cart: openCart, card: visa),
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
    'reset after a failure goes back to ready',
    build: build,
    act: (cubit) async {
      await cubit.placeOrder(user: user, cart: openCart, card: failing);
      cubit.reset();
    },
    expect: () => const [
      CheckoutState(
        status: CheckoutStatus.failure,
        errorMessage: CheckoutCubit.declinedMessage,
      ),
      CheckoutState(),
    ],
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'after a decline, another card can be used',
    build: build,
    act: (cubit) async {
      await cubit.placeOrder(user: user, cart: openCart, card: failing);
      cubit.reset();
      await cubit.placeOrder(user: user, cart: openCart, card: visa);
    },
    expect: () => const [
      CheckoutState(
        status: CheckoutStatus.failure,
        errorMessage: CheckoutCubit.declinedMessage,
      ),
      CheckoutState(),
      placing,
      CheckoutState(status: CheckoutStatus.placed, orderId: 'o1'),
    ],
    verify: (_) => expect(savedOrder(orders).cardLast4, '4242'),
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'reset does nothing when ready or placed',
    build: build,
    act: (cubit) async {
      cubit.reset();
      await cubit.placeOrder(user: user, cart: openCart);
      cubit.reset();
    },
    expect: () => const [
      placing,
      CheckoutState(status: CheckoutStatus.placed, orderId: 'o1'),
    ],
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'no phone: nothing is saved, and it asks for a phone',
    build: build,
    act: (cubit) => cubit.placeOrder(user: noPhoneUser, cart: openCart),
    expect: () => const [phoneNeeded],
    verify: (_) => verifyNever(() => orders.placeOrder(any())),
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'a wrong phone is treated like no phone',
    build: build,
    act: (cubit) => cubit.placeOrder(
      user: const AppUser(
        uid: 'u1',
        name: 'Nimal',
        email: 'nimal@test.com',
        phone: '0112345678',
        role: UserRole.customer,
      ),
      cart: openCart,
    ),
    expect: () => const [phoneNeeded],
    verify: (_) => verifyNever(() => orders.placeOrder(any())),
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'no phone also stops a card order',
    build: build,
    act: (cubit) => cubit.placeOrder(
      user: noPhoneUser,
      cart: openCart,
      card: visa,
    ),
    expect: () => const [phoneNeeded],
    verify: (_) => verifyNever(() => orders.placeOrder(any())),
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'a phone with spaces is saved as digits only',
    build: build,
    act: (cubit) => cubit.placeOrder(
      user: const AppUser(
        uid: 'u1',
        name: 'Nimal',
        email: 'nimal@test.com',
        phone: '077 123 4567',
        role: UserRole.customer,
      ),
      cart: openCart,
    ),
    verify: (_) => expect(savedOrder(orders).customerPhone, '0771234567'),
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'a card order saves the phone too',
    build: build,
    act: (cubit) =>
        cubit.placeOrder(user: user, cart: openCart, card: visa),
    verify: (_) => expect(savedOrder(orders).customerPhone, '0712345678'),
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'after adding a phone, the order can be placed',
    build: build,
    act: (cubit) async {
      await cubit.placeOrder(user: noPhoneUser, cart: openCart);
      await cubit.placeOrder(user: user, cart: openCart);
    },
    expect: () => const [
      phoneNeeded,
      placing,
      CheckoutState(status: CheckoutStatus.placed, orderId: 'o1'),
    ],
  );
}