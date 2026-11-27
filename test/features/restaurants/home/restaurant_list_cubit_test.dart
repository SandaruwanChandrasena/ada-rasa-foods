import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant_repository.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/home/restaurant_list_cubit.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/home/restaurant_list_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRestaurantRepository extends Mock implements RestaurantRepository {}

Restaurant restaurant(
  String id,
  String name,
  String cuisine, {
  bool isOpen = true,
  bool isActive = true,
}) {
  return Restaurant(
    id: id,
    name: name,
    cuisine: cuisine,
    ownerId: 'owner_$id',
    address: 'Colombo',
    latitude: 6.9,
    longitude: 79.8,
    isOpen: isOpen,
    isActive: isActive,
  );
}

final hotel = restaurant('r1', 'Hotel De Kottu', 'Sri Lankan');
final dragon = restaurant('r2', 'Dragon Wok', 'Chinese');
final pizza = restaurant('r3', 'Pizza Corner', 'Pizza', isOpen: false);
final rice = restaurant('r4', 'Rice and Curry House', 'Sri Lankan');
final all = [hotel, dragon, pizza, rice];

final loaded = RestaurantListState(
  status: RestaurantListStatus.loaded,
  restaurants: all,
);

void main() {
  late MockRestaurantRepository repository;

  setUp(() {
    repository = MockRestaurantRepository();
  });

  test('starts in the loading state', () {
    final cubit = RestaurantListCubit(repository);
    expect(cubit.state, const RestaurantListState());
    cubit.close();
  });

  blocTest<RestaurantListCubit, RestaurantListState>(
    'start shows loading, then the restaurants',
    setUp: () {
      when(() => repository.watchActiveRestaurants())
          .thenAnswer((_) => Stream.value(all));
    },
    build: () => RestaurantListCubit(repository),
    act: (cubit) => cubit.start(),
    expect: () => [const RestaurantListState(), loaded],
  );

  blocTest<RestaurantListCubit, RestaurantListState>(
    'a DataFailure shows its own message',
    setUp: () {
      when(() => repository.watchActiveRestaurants()).thenAnswer(
        (_) => Stream.error(const DataFailure('No internet connection.')),
      );
    },
    build: () => RestaurantListCubit(repository),
    act: (cubit) => cubit.start(),
    expect: () => [
      const RestaurantListState(),
      const RestaurantListState(
        status: RestaurantListStatus.failure,
        errorMessage: 'No internet connection.',
      ),
    ],
  );

  blocTest<RestaurantListCubit, RestaurantListState>(
    'any other error shows a simple message',
    setUp: () {
      when(() => repository.watchActiveRestaurants())
          .thenAnswer((_) => Stream.error(Exception('boom')));
    },
    build: () => RestaurantListCubit(repository),
    act: (cubit) => cubit.start(),
    expect: () => [
      const RestaurantListState(),
      const RestaurantListState(
        status: RestaurantListStatus.failure,
        errorMessage: 'Something went wrong. Please try again.',
      ),
    ],
  );

  blocTest<RestaurantListCubit, RestaurantListState>(
    'search by name ignores capital letters and spaces',
    build: () => RestaurantListCubit(repository),
    seed: () => loaded,
    act: (cubit) => cubit.search('  dragon '),
    verify: (cubit) {
      expect(cubit.state.visibleRestaurants, [dragon]);
    },
  );

  blocTest<RestaurantListCubit, RestaurantListState>(
    'search by cuisine',
    build: () => RestaurantListCubit(repository),
    seed: () => loaded,
    act: (cubit) => cubit.search('sri lankan'),
    verify: (cubit) {
      expect(cubit.state.visibleRestaurants, [hotel, rice]);
    },
  );

  blocTest<RestaurantListCubit, RestaurantListState>(
    'search with no match gives an empty list',
    build: () => RestaurantListCubit(repository),
    seed: () => loaded,
    act: (cubit) => cubit.search('xyz'),
    verify: (cubit) {
      expect(cubit.state.visibleRestaurants, isEmpty);
    },
  );

  blocTest<RestaurantListCubit, RestaurantListState>(
    'a cuisine chip shows only that cuisine',
    build: () => RestaurantListCubit(repository),
    seed: () => loaded,
    act: (cubit) => cubit.selectCuisine('Sri Lankan'),
    verify: (cubit) {
      expect(cubit.state.selectedCuisine, 'Sri Lankan');
      expect(cubit.state.visibleRestaurants, [hotel, rice]);
    },
  );

  // verify runs after the cubit is closed, so all actions go in act.
  blocTest<RestaurantListCubit, RestaurantListState>(
    'the All chip shows everything again',
    build: () => RestaurantListCubit(repository),
    seed: () => loaded.copyWith(selectedCuisine: () => 'Sri Lankan'),
    act: (cubit) => cubit.selectCuisine(null),
    verify: (cubit) {
      expect(cubit.state.selectedCuisine, isNull);
      // Pizza Corner is closed, so it moves to the end.
      expect(cubit.state.visibleRestaurants, [hotel, dragon, rice, pizza]);
    },
  );

  blocTest<RestaurantListCubit, RestaurantListState>(
    'search and chip work together',
    build: () => RestaurantListCubit(repository),
    seed: () => loaded,
    act: (cubit) {
      cubit.selectCuisine('Sri Lankan');
      cubit.search('rice');
    },
    verify: (cubit) {
      expect(cubit.state.visibleRestaurants, [rice]);
    },
  );

  test('closed restaurants stay in the list', () {
    expect(loaded.visibleRestaurants, contains(pizza));
  });

  group('closed places go last', () {
    RestaurantListState stateWith(List<Restaurant> restaurants) {
      return RestaurantListState(
        status: RestaurantListStatus.loaded,
        restaurants: restaurants,
      );
    }

    test('a closed place moves to the end, open ones keep their order', () {
      expect(loaded.visibleRestaurants, [hotel, dragon, rice, pizza]);
    });

    test('closed places keep their own order at the end', () {
      final shut1 = restaurant('c1', 'Shut One', 'Pizza', isOpen: false);
      final shut2 = restaurant('c2', 'Shut Two', 'Pizza', isOpen: false);

      final state = stateWith([shut1, hotel, shut2, dragon]);

      expect(state.visibleRestaurants, [hotel, dragon, shut1, shut2]);
    });

    test('a place turned off by the admin also goes last', () {
      final off = restaurant('x1', 'Turned Off', 'Chinese', isActive: false);

      final state = stateWith([off, hotel, dragon]);

      expect(state.visibleRestaurants, [hotel, dragon, off]);
    });

    test('with every place open, the order does not change', () {
      final state = stateWith([rice, dragon, hotel]);

      expect(state.visibleRestaurants, [rice, dragon, hotel]);
    });

    test('the order also works with a cuisine picked', () {
      final shutRice = restaurant(
        'c3',
        'Shut Rice',
        'Sri Lankan',
        isOpen: false,
      );
      final state = stateWith([shutRice, hotel, dragon, rice])
          .copyWith(selectedCuisine: () => 'Sri Lankan');

      expect(state.visibleRestaurants, [hotel, rice, shutRice]);
    });

    test('a place that closes while the list is open moves down', () {
      final closedDragon = restaurant('r2', 'Dragon Wok', 'Chinese',
          isOpen: false);
      final before = stateWith([hotel, dragon, rice]);
      final after = before.copyWith(restaurants: [hotel, closedDragon, rice]);

      expect(before.visibleRestaurants, [hotel, dragon, rice]);
      expect(after.visibleRestaurants, [hotel, rice, closedDragon]);
    });
  });

  test('chips are the cuisines, A to Z, with no copies or empty names', () {
    final state = RestaurantListState(
      status: RestaurantListStatus.loaded,
      restaurants: [...all, restaurant('r5', 'No Cuisine', '  ')],
    );
    expect(state.cuisines, ['Chinese', 'Pizza', 'Sri Lankan']);
  });

  test('the chip goes back to All when its cuisine is gone', () async {
    final controller = StreamController<List<Restaurant>>();
    when(() => repository.watchActiveRestaurants())
        .thenAnswer((_) => controller.stream);
    final cubit = RestaurantListCubit(repository)..start();

    controller.add(all);
    await Future<void>.delayed(Duration.zero);
    cubit.selectCuisine('Chinese');

    // The only Chinese restaurant is turned off.
    controller.add([hotel, pizza, rice]);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.selectedCuisine, isNull);
    // Pizza Corner is closed, so it is shown last.
    expect(cubit.state.visibleRestaurants, [hotel, rice, pizza]);

    await cubit.close();
    await controller.close();
  });

  test('close stops listening to Firestore', () async {
    final controller = StreamController<List<Restaurant>>();
    when(() => repository.watchActiveRestaurants())
        .thenAnswer((_) => controller.stream);
    final cubit = RestaurantListCubit(repository)..start();
    expect(controller.hasListener, isTrue);

    await cubit.close();
    expect(controller.hasListener, isFalse);
    await controller.close();
  });
}