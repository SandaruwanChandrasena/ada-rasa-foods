import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant_repository.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/my_restaurant_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRestaurantRepository extends Mock implements RestaurantRepository {}

Restaurant kottu({bool isOpen = true}) {
  return Restaurant(
    id: 'r1',
    name: 'Kottu Corner',
    cuisine: 'Sri Lankan',
    ownerId: 'o1',
    address: 'Colombo',
    latitude: 6.9,
    longitude: 79.8,
    isOpen: isOpen,
  );
}

// Lets stream events reach the cubit.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late MockRestaurantRepository repository;
  late StreamController<Restaurant?> stream;

  setUp(() {
    repository = MockRestaurantRepository();
    stream = StreamController<Restaurant?>.broadcast();
    when(() => repository.watchRestaurant('r1'))
        .thenAnswer((_) => stream.stream);
    when(
      () => repository.setOpen(any(), isOpen: any(named: 'isOpen')),
    ).thenAnswer((_) async {});
  });

  tearDown(() => stream.close());

  Future<MyRestaurantCubit> started({Restaurant? restaurant}) async {
    final cubit = MyRestaurantCubit(repository);
    await cubit.start('r1');
    stream.add(restaurant ?? kottu());
    await settle();
    return cubit;
  }

  test('starts loading', () {
    expect(
      MyRestaurantCubit(repository).state,
      const MyRestaurantState(),
    );
  });

  test('shows the restaurant when it arrives', () async {
    final cubit = await started();

    expect(cubit.state.view, MyRestaurantView.loaded);
    expect(cubit.state.restaurant!.name, 'Kottu Corner');
    expect(cubit.state.canSwitch, isTrue);
    await cubit.close();
  });

  test('says not found when the restaurant is missing', () async {
    final cubit = MyRestaurantCubit(repository);
    await cubit.start('r1');

    stream.add(null);
    await settle();

    expect(cubit.state.view, MyRestaurantView.notFound);
    expect(cubit.state.canSwitch, isFalse);
    await cubit.close();
  });

  test('a load error shows failure, and retry starts again', () async {
    final cubit = MyRestaurantCubit(repository);
    await cubit.start('r1');
    stream.addError(const DataFailure('No internet connection.'));
    await settle();

    expect(cubit.state.view, MyRestaurantView.failure);

    cubit.retry();
    await settle();
    stream.add(kottu());
    await settle();

    expect(cubit.state.view, MyRestaurantView.loaded);
    verify(() => repository.watchRestaurant('r1')).called(2);
    await cubit.close();
  });

  test('a live change updates the switch', () async {
    final cubit = await started();

    stream.add(kottu(isOpen: false));
    await settle();

    expect(cubit.state.restaurant!.isOpen, isFalse);
    await cubit.close();
  });

  test('closing saves and shows a message', () async {
    final cubit = await started();

    await cubit.setOpen(false);

    verify(() => repository.setOpen('r1', isOpen: false)).called(1);
    expect(
      cubit.state.notice,
      'Your restaurant is closed. Customers cannot order.',
    );
    expect(cubit.state.noticeId, 1);
    expect(cubit.state.isSaving, isFalse);
    await cubit.close();
  });

  test('opening saves and shows a message', () async {
    final cubit = await started(restaurant: kottu(isOpen: false));

    await cubit.setOpen(true);

    verify(() => repository.setOpen('r1', isOpen: true)).called(1);
    expect(
      cubit.state.notice,
      'Your restaurant is open. Customers can order now.',
    );
    await cubit.close();
  });

  test('the same value again does nothing', () async {
    final cubit = await started();

    await cubit.setOpen(true);

    verifyNever(
      () => repository.setOpen(any(), isOpen: any(named: 'isOpen')),
    );
    await cubit.close();
  });

  test('the switch is locked while saving', () async {
    final save = Completer<void>();
    when(
      () => repository.setOpen(any(), isOpen: any(named: 'isOpen')),
    ).thenAnswer((_) => save.future);
    final cubit = await started();

    final first = cubit.setOpen(false);
    await settle();
    expect(cubit.state.isSaving, isTrue);
    expect(cubit.state.canSwitch, isFalse);

    await cubit.setOpen(false);
    save.complete();
    await first;

    verify(
      () => repository.setOpen(any(), isOpen: any(named: 'isOpen')),
    ).called(1);
    expect(cubit.state.isSaving, isFalse);
    await cubit.close();
  });

  test('a save error shows the reason', () async {
    when(
      () => repository.setOpen(any(), isOpen: any(named: 'isOpen')),
    ).thenThrow(
      const DataFailure('No internet connection. Please try again.'),
    );
    final cubit = await started();

    await cubit.setOpen(false);

    expect(
      cubit.state.notice,
      'No internet connection. Please try again.',
    );
    expect(cubit.state.isSaving, isFalse);
    await cubit.close();
  });

  test('cannot switch before the restaurant loads', () async {
    final cubit = MyRestaurantCubit(repository);
    await cubit.start('r1');

    await cubit.setOpen(false);

    verifyNever(
      () => repository.setOpen(any(), isOpen: any(named: 'isOpen')),
    );
    await cubit.close();
  });
}