import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:ada_rasa_foods/features/menu/domain/menu_repository.dart';
import 'package:ada_rasa_foods/features/menu/presentation/menu_manage_cubit.dart';
import 'package:ada_rasa_foods/features/menu/presentation/menu_manage_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMenuRepository extends Mock implements MenuRepository {}

Dish dish(
  String id, {
  String name = 'Chicken Kottu',
  String category = 'Kottu',
  bool available = true,
}) {
  return Dish(
    id: id,
    restaurantId: 'r1',
    name: name,
    price: 1200,
    category: category,
    available: available,
  );
}

// Lets stream events reach the cubit.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late MockMenuRepository repository;
  late StreamController<List<Dish>> menu;

  final kottu = dish('d1');
  final milo = dish('d2', name: 'Iced Milo', category: 'Drinks');

  setUpAll(() => registerFallbackValue(dish('fallback')));

  setUp(() {
    repository = MockMenuRepository();
    menu = StreamController<List<Dish>>.broadcast();
    when(() => repository.watchMenu('r1')).thenAnswer((_) => menu.stream);
    when(
      () => repository.setAvailable(any(), available: any(named: 'available')),
    ).thenAnswer((_) async {});
  });

  tearDown(() => menu.close());

  Future<MenuManageCubit> started(List<Dish> dishes) async {
    final cubit = MenuManageCubit(repository);
    await cubit.start('r1');
    menu.add(dishes);
    await settle();
    return cubit;
  }

  test('starts loading', () {
    expect(MenuManageCubit(repository).state, const MenuManageState());
  });

  test('shows the dishes when they arrive', () async {
    final cubit = await started([milo, kottu]);

    expect(cubit.state.view, MenuView.loaded);
    expect(cubit.state.dishes, [milo, kottu]);
    await cubit.close();
  });

  test('lists each category once, in menu order', () async {
    final cubit = await started([
      milo,
      dish('d3', name: 'Faluda', category: 'Drinks'),
      kottu,
    ]);

    expect(cubit.state.categories, ['Drinks', 'Kottu']);
    expect(cubit.state.dishesIn('Drinks'), hasLength(2));
    await cubit.close();
  });

  blocTest<MenuManageCubit, MenuManageState>(
    'a load error shows the message',
    build: () => MenuManageCubit(repository),
    act: (cubit) async {
      await cubit.start('r1');
      menu.addError(const DataFailure('No internet connection.'));
      await settle();
    },
    expect: () => [
      const MenuManageState(),
      const MenuManageState(
        view: MenuView.failure,
        errorMessage: 'No internet connection.',
      ),
    ],
  );

  test('retry starts watching again', () async {
    final cubit = MenuManageCubit(repository);
    await cubit.start('r1');
    menu.addError(const DataFailure('No internet connection.'));
    await settle();

    cubit.retry();
    await settle();
    menu.add([kottu]);
    await settle();

    expect(cubit.state.view, MenuView.loaded);
    verify(() => repository.watchMenu('r1')).called(2);
    await cubit.close();
  });

  test('hiding a dish saves and shows a message', () async {
    final cubit = await started([kottu]);

    await cubit.setAvailable(kottu, available: false);

    verify(() => repository.setAvailable(kottu, available: false)).called(1);
    expect(cubit.state.notice, 'Chicken Kottu is hidden from customers.');
    expect(cubit.state.busyIds, isEmpty);
    await cubit.close();
  });

  test('showing a dish again saves and shows a message', () async {
    final hidden = dish('d1', available: false);
    final cubit = await started([hidden]);

    await cubit.setAvailable(hidden, available: true);

    verify(() => repository.setAvailable(hidden, available: true)).called(1);
    expect(cubit.state.notice, 'Chicken Kottu is now available.');
    await cubit.close();
  });

  test('the same value again does nothing', () async {
    final cubit = await started([kottu]);

    await cubit.setAvailable(kottu, available: true);

    verifyNever(
      () => repository.setAvailable(any(), available: any(named: 'available')),
    );
    await cubit.close();
  });

  test('the dish is busy while saving, and a second tap does nothing',
      () async {
    final save = Completer<void>();
    when(
      () => repository.setAvailable(any(), available: any(named: 'available')),
    ).thenAnswer((_) => save.future);
    final cubit = await started([kottu]);

    final first = cubit.setAvailable(kottu, available: false);
    await settle();
    expect(cubit.state.isBusy(kottu), isTrue);

    await cubit.setAvailable(kottu, available: false);
    save.complete();
    await first;

    expect(cubit.state.isBusy(kottu), isFalse);
    verify(
      () => repository.setAvailable(any(), available: any(named: 'available')),
    ).called(1);
    await cubit.close();
  });

  test('a save error shows the reason', () async {
    when(
      () => repository.setAvailable(any(), available: any(named: 'available')),
    ).thenThrow(const DataFailure('This dish was not found.'));
    final cubit = await started([kottu]);

    await cubit.setAvailable(kottu, available: false);

    expect(cubit.state.notice, 'This dish was not found.');
    expect(cubit.state.busyIds, isEmpty);
    await cubit.close();
  });
}