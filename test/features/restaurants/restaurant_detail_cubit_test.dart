import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:ada_rasa_foods/features/menu/domain/menu_repository.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant_repository.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/restaurant_detail_cubit.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/restaurant_detail_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRestaurantRepository extends Mock implements RestaurantRepository {}

class MockMenuRepository extends Mock implements MenuRepository {}

const restaurantId = 'r1';

const hotel = Restaurant(
  id: restaurantId,
  name: 'Hotel De Kottu',
  cuisine: 'Sri Lankan',
  ownerId: 'owner_r1',
  address: 'Colombo',
  latitude: 6.9,
  longitude: 79.8,
);

Dish dish(String id, String name, String category, {bool available = true}) {
  return Dish(
    id: id,
    restaurantId: restaurantId,
    name: name,
    price: 1200,
    category: category,
    available: available,
  );
}

final kottu = dish('d1', 'Chicken Kottu', 'Kottu');
final cheeseKottu = dish('d2', 'Cheese Kottu', 'Kottu', available: false);
final faluda = dish('d3', 'Faluda', 'Drinks');
final menu = [faluda, cheeseKottu, kottu];

void main() {
  late MockRestaurantRepository restaurantRepository;
  late MockMenuRepository menuRepository;

  setUp(() {
    restaurantRepository = MockRestaurantRepository();
    menuRepository = MockMenuRepository();
  });

  RestaurantDetailCubit buildCubit() =>
      RestaurantDetailCubit(restaurantRepository, menuRepository);

  void stubStreams({
    required Stream<Restaurant?> restaurant,
    required Stream<List<Dish>> dishes,
  }) {
    when(() => restaurantRepository.watchRestaurant(restaurantId))
        .thenAnswer((_) => restaurant);
    when(() => menuRepository.watchMenu(restaurantId))
        .thenAnswer((_) => dishes);
  }

  test('starts in the loading state', () {
    final cubit = buildCubit();
    expect(cubit.state, const RestaurantDetailState());
    cubit.close();
  });

  blocTest<RestaurantDetailCubit, RestaurantDetailState>(
    'shows the restaurant and its menu when both arrive',
    setUp: () => stubStreams(
      restaurant: Stream.value(hotel),
      dishes: Stream.value(menu),
    ),
    build: buildCubit,
    act: (cubit) => cubit.start(restaurantId),
    expect: () => [
      const RestaurantDetailState(),
      RestaurantDetailState(
        status: RestaurantDetailStatus.loaded,
        restaurant: hotel,
        dishes: menu,
      ),
    ],
  );

  blocTest<RestaurantDetailCubit, RestaurantDetailState>(
    'a missing restaurant shows not found',
    setUp: () => stubStreams(
      restaurant: Stream.value(null),
      dishes: Stream.value(const []),
    ),
    build: buildCubit,
    act: (cubit) => cubit.start(restaurantId),
    expect: () => [
      const RestaurantDetailState(),
      const RestaurantDetailState(status: RestaurantDetailStatus.notFound),
    ],
  );

  blocTest<RestaurantDetailCubit, RestaurantDetailState>(
    'a turned-off restaurant shows not found',
    setUp: () => stubStreams(
      restaurant: Stream.value(
        const Restaurant(
          id: restaurantId,
          name: 'Hotel De Kottu',
          cuisine: 'Sri Lankan',
          ownerId: 'owner_r1',
          address: 'Colombo',
          latitude: 6.9,
          longitude: 79.8,
          isActive: false,
        ),
      ),
      dishes: Stream.value(menu),
    ),
    build: buildCubit,
    act: (cubit) => cubit.start(restaurantId),
    expect: () => [
      const RestaurantDetailState(),
      const RestaurantDetailState(status: RestaurantDetailStatus.notFound),
    ],
  );

  blocTest<RestaurantDetailCubit, RestaurantDetailState>(
    'an error shows the failure message',
    setUp: () => stubStreams(
      restaurant: Stream.error(const DataFailure('No internet connection.')),
      dishes: Stream.value(menu),
    ),
    build: buildCubit,
    act: (cubit) => cubit.start(restaurantId),
    expect: () => [
      const RestaurantDetailState(),
      const RestaurantDetailState(
        status: RestaurantDetailStatus.failure,
        errorMessage: 'No internet connection.',
      ),
    ],
  );

  test('waits for the menu before showing the page', () async {
    final restaurantController = StreamController<Restaurant?>();
    final menuController = StreamController<List<Dish>>();
    stubStreams(
      restaurant: restaurantController.stream,
      dishes: menuController.stream,
    );
    final cubit = buildCubit()..start(restaurantId);

    restaurantController.add(hotel);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, RestaurantDetailStatus.loading);

    menuController.add(menu);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, RestaurantDetailStatus.loaded);

    await cubit.close();
    await restaurantController.close();
    await menuController.close();
  });

  test('a live change to the restaurant updates the page', () async {
    final restaurantController = StreamController<Restaurant?>();
    stubStreams(
      restaurant: restaurantController.stream,
      dishes: Stream.value(menu),
    );
    final cubit = buildCubit()..start(restaurantId);

    restaurantController.add(hotel);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.restaurant?.isOpen, isTrue);

    // The owner closes the restaurant.
    restaurantController.add(
      const Restaurant(
        id: restaurantId,
        name: 'Hotel De Kottu',
        cuisine: 'Sri Lankan',
        ownerId: 'owner_r1',
        address: 'Colombo',
        latitude: 6.9,
        longitude: 79.8,
        isOpen: false,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, RestaurantDetailStatus.loaded);
    expect(cubit.state.restaurant?.isOpen, isFalse);

    await cubit.close();
    await restaurantController.close();
  });

  test('close stops listening to both streams', () async {
    final restaurantController = StreamController<Restaurant?>();
    final menuController = StreamController<List<Dish>>();
    stubStreams(
      restaurant: restaurantController.stream,
      dishes: menuController.stream,
    );
    final cubit = buildCubit()..start(restaurantId);
    expect(restaurantController.hasListener, isTrue);
    expect(menuController.hasListener, isTrue);

    await cubit.close();
    expect(restaurantController.hasListener, isFalse);
    expect(menuController.hasListener, isFalse);

    await restaurantController.close();
    await menuController.close();
  });

  group('menuSections', () {
    test('groups dishes by category and keeps the order', () {
      final state = RestaurantDetailState(
        status: RestaurantDetailStatus.loaded,
        restaurant: hotel,
        dishes: menu,
      );
      expect(state.menuSections.keys, ['Drinks', 'Kottu']);
      expect(state.menuSections['Kottu'], [cheeseKottu, kottu]);
    });

    test('a dish with no category goes under Other', () {
      final state = RestaurantDetailState(
        dishes: [dish('d9', 'Water', '  ')],
      );
      expect(state.menuSections.keys, ['Other']);
    });
  });
}