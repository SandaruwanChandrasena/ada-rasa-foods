import 'dart:async';

import 'package:ada_rasa_foods/features/cart/domain/cart.dart';
import 'package:ada_rasa_foods/features/cart/domain/cart_repository.dart';
import 'package:ada_rasa_foods/features/cart/presentation/cart_cubit.dart';
import 'package:ada_rasa_foods/features/cart/presentation/cart_state.dart';
import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:ada_rasa_foods/features/menu/domain/menu_repository.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCartRepository extends Mock implements CartRepository {}

class MockRestaurantRepository extends Mock implements RestaurantRepository {}

class MockMenuRepository extends Mock implements MenuRepository {}

Restaurant restaurant({bool isOpen = true, bool isActive = true}) {
  return Restaurant(
    id: 'r1',
    name: 'Kottu Corner',
    cuisine: 'Sri Lankan',
    ownerId: 'owner_r1',
    address: 'Colombo',
    latitude: 6.9,
    longitude: 79.8,
    isOpen: isOpen,
    isActive: isActive,
  );
}

Dish dish(
  String id,
  String name,
  int price, {
  String restaurantId = 'r1',
  bool available = true,
}) {
  return Dish(
    id: id,
    restaurantId: restaurantId,
    name: name,
    price: price,
    category: 'Menu',
    available: available,
  );
}

final milo = dish('d1', 'Iced Milo', 450);
final kottu = dish('d2', 'Dolphin Kottu', 1400);
final kottuGone = dish('d2', 'Dolphin Kottu', 1400, available: false);
final pizza = dish('p1', 'Cheese Pizza', 2000, restaurantId: 'r2');

// Lets stream events reach the cubit.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late MockCartRepository cartRepository;
  late MockRestaurantRepository restaurantRepository;
  late MockMenuRepository menuRepository;
  late StreamController<Restaurant?> restaurantStream;
  late StreamController<List<Dish>> menuStream;
  late DateTime now;
  late CartCubit cubit;

  setUpAll(() => registerFallbackValue(Cart.empty));

  setUp(() {
    cartRepository = MockCartRepository();
    restaurantRepository = MockRestaurantRepository();
    menuRepository = MockMenuRepository();
    restaurantStream = StreamController<Restaurant?>.broadcast();
    menuStream = StreamController<List<Dish>>.broadcast();
    now = DateTime(2026, 10, 29, 10);

    when(() => cartRepository.loadCart(any()))
        .thenAnswer((_) async => Cart.empty);
    when(() => cartRepository.saveCart(any(), any())).thenAnswer((_) async {});
    when(() => restaurantRepository.watchRestaurant(any()))
        .thenAnswer((_) => restaurantStream.stream);
    when(() => menuRepository.watchMenu(any()))
        .thenAnswer((_) => menuStream.stream);

    cubit = CartCubit(
      cartRepository,
      restaurantRepository,
      menuRepository,
      clock: () => now,
    );
  });

  tearDown(() async {
    await cubit.close();
    await restaurantStream.close();
    await menuStream.close();
  });

  // Signs in a customer and adds Iced Milo and Dolphin Kottu.
  Future<void> cartWithTwoDishes() async {
    await cubit.setUser('u1');
    cubit.addDish(milo, restaurantName: 'Kottu Corner');
    cubit.addDish(kottu, restaurantName: 'Kottu Corner');
    restaurantStream.add(restaurant());
    menuStream.add([milo, kottu]);
    await settle();
  }

  group('user', () {
    test('setUser loads the saved cart of that user', () async {
      final saved = Cart.empty.addDish(
        milo,
        restaurantName: 'Kottu Corner',
        now: now,
      );
      when(() => cartRepository.loadCart('u1')).thenAnswer((_) async => saved);

      await cubit.setUser('u1');

      expect(cubit.state.userId, 'u1');
      expect(cubit.state.cart, saved);
    });

    test('setUser(null) empties the cart on screen', () async {
      await cartWithTwoDishes();
      await cubit.setUser(null);

      expect(cubit.state, const CartState());
    });

    test('adding with no user gives noUser', () {
      expect(
        cubit.addDish(milo, restaurantName: 'Kottu Corner'),
        AddToCartResult.noUser,
      );
    });
  });

  group('add and change', () {
    setUp(() => cubit.setUser('u1'));

    test('addDish adds the dish and saves the cart', () async {
      await settle();
      final result = cubit.addDish(milo, restaurantName: 'Kottu Corner');

      expect(result, AddToCartResult.added);
      expect(cubit.state.cart.quantityOf('d1'), 1);
      verify(() => cartRepository.saveCart('u1', cubit.state.cart)).called(1);
    });

    test('a dish from another restaurant asks first (CUS-13)', () async {
      await settle();
      cubit.addDish(milo, restaurantName: 'Kottu Corner');
      final before = cubit.state.cart;

      final result = cubit.addDish(pizza, restaurantName: 'Pizza Corner');

      expect(result, AddToCartResult.otherRestaurant);
      expect(cubit.state.cart, before);
    });

    test('clearAndAdd starts a new cart with the new dish', () async {
      await settle();
      cubit.addDish(milo, restaurantName: 'Kottu Corner');
      cubit.clearAndAdd(pizza, restaurantName: 'Pizza Corner');

      expect(cubit.state.cart.restaurantId, 'r2');
      expect(cubit.state.cart.items.single.dishId, 'p1');
    });

    test('the 21st one gives maxReached', () async {
      await settle();
      for (var i = 0; i < Cart.maxQuantity; i++) {
        cubit.addDish(milo, restaurantName: 'Kottu Corner');
      }

      expect(
        cubit.addDish(milo, restaurantName: 'Kottu Corner'),
        AddToCartResult.maxReached,
      );
      expect(cubit.state.cart.quantityOf('d1'), 20);
    });

    test('increase, decrease, remove, and clear', () async {
      await settle();
      cubit.addDish(milo, restaurantName: 'Kottu Corner');
      cubit.addDish(kottu, restaurantName: 'Kottu Corner');

      cubit.increase('d1');
      expect(cubit.state.cart.quantityOf('d1'), 2);

      cubit.decrease('d1');
      expect(cubit.state.cart.quantityOf('d1'), 1);

      cubit.remove('d2');
      expect(cubit.state.cart.quantityOf('d2'), 0);

      cubit.clear();
      expect(cubit.state.cart.isEmpty, isTrue);
    });
  });

  test('a cart older than 1 day starts again when you add', () async {
    final old = Cart.empty.addDish(
      milo,
      restaurantName: 'Kottu Corner',
      now: now.subtract(const Duration(days: 2)),
    );
    when(() => cartRepository.loadCart('u1')).thenAnswer((_) async => old);
    await cubit.setUser('u1');

    // Not "otherRestaurant", because the old cart does not count.
    final result = cubit.addDish(pizza, restaurantName: 'Pizza Corner');

    expect(result, AddToCartResult.added);
    expect(cubit.state.cart.restaurantId, 'r2');
  });

  group('live restaurant and menu', () {
    test('an open restaurant with all dishes allows checkout', () async {
      await cartWithTwoDishes();

      expect(cubit.state.restaurantStatus, CartRestaurantStatus.open);
      expect(cubit.state.itemCount, 2);
      expect(cubit.state.total, 1850);
      expect(cubit.state.hasProblem, isFalse);
      expect(cubit.state.canCheckout, isTrue);
    });

    test('a dish that is not available stops counting', () async {
      await cartWithTwoDishes();

      menuStream.add([milo, kottuGone]);
      await settle();

      expect(cubit.state.unavailableDishIds, {'d2'});
      expect(cubit.state.itemCount, 1);
      expect(cubit.state.total, 450);
      expect(cubit.state.hasProblem, isTrue);
      expect(cubit.state.canCheckout, isFalse);
      expect(cubit.state.noticeId, 1);
      expect(
        cubit.state.notice,
        contains('Dolphin Kottu is not available now'),
      );
    });

    test('a dish that comes back counts again', () async {
      await cartWithTwoDishes();
      menuStream.add([milo, kottuGone]);
      await settle();

      menuStream.add([milo, kottu]);
      await settle();

      expect(cubit.state.unavailableDishIds, isEmpty);
      expect(cubit.state.itemCount, 2);
    });

    test('a dish removed from the menu counts as not available', () async {
      await cartWithTwoDishes();

      menuStream.add([milo]);
      await settle();

      expect(cubit.state.isDishAvailable('d2'), isFalse);
    });

    test('removing the not available dish allows checkout again', () async {
      await cartWithTwoDishes();
      menuStream.add([milo, kottuGone]);
      await settle();

      cubit.remove('d2');

      expect(cubit.state.hasProblem, isFalse);
      expect(cubit.state.canCheckout, isTrue);
    });

    test('a closed restaurant blocks checkout but keeps the count', () async {
      await cartWithTwoDishes();

      restaurantStream.add(restaurant(isOpen: false));
      await settle();

      expect(cubit.state.restaurantStatus, CartRestaurantStatus.closed);
      expect(cubit.state.itemCount, 2);
      expect(cubit.state.canCheckout, isFalse);
      expect(cubit.state.notice, 'Kottu Corner is closed now. '
          'You can order when it opens.');

      restaurantStream.add(restaurant());
      await settle();

      expect(cubit.state.notice, 'Kottu Corner is open again.');
      expect(cubit.state.canCheckout, isTrue);
    });

    test('a turned-off restaurant counts nothing', () async {
      await cartWithTwoDishes();

      restaurantStream.add(restaurant(isActive: false));
      await settle();

      expect(cubit.state.restaurantStatus, CartRestaurantStatus.unavailable);
      expect(cubit.state.itemCount, 0);
      expect(cubit.state.total, 0);
      expect(cubit.state.problemMessage, contains('not available now'));
    });

    test('a deleted restaurant counts as not available', () async {
      await cartWithTwoDishes();

      restaurantStream.add(null);
      await settle();

      expect(cubit.state.restaurantStatus, CartRestaurantStatus.unavailable);
    });

    test('a new price from the menu updates the total and saves', () async {
      await cartWithTwoDishes();
      clearInteractions(cartRepository);

      menuStream.add([dish('d1', 'Iced Milo', 500), kottu]);
      await settle();

      expect(cubit.state.total, 500 + 1400);
      verify(() => cartRepository.saveCart('u1', any())).called(1);
    });

    test('stops watching when the cart is empty', () async {
      await cartWithTwoDishes();
      expect(menuStream.hasListener, isTrue);

      cubit.clear();
      await settle();

      expect(menuStream.hasListener, isFalse);
      expect(restaurantStream.hasListener, isFalse);
    });

    test('close stops watching', () async {
      await cartWithTwoDishes();
      await cubit.close();

      expect(menuStream.hasListener, isFalse);
      expect(restaurantStream.hasListener, isFalse);
    });
  });
}