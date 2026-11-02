import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:ada_rasa_foods/features/menu/domain/menu_repository.dart';
import 'package:ada_rasa_foods/features/menu/presentation/dish_form_cubit.dart';
import 'package:ada_rasa_foods/features/menu/presentation/dish_form_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMenuRepository extends Mock implements MenuRepository {}

const kottu = Dish(
  id: 'd1',
  restaurantId: 'r1',
  name: 'Chicken Kottu',
  price: 1200,
  category: 'Kottu',
  description: 'Spicy.',
  imageUrl: 'https://example.com/kottu.jpg',
);

void main() {
  late MockMenuRepository repository;

  setUpAll(() => registerFallbackValue(kottu));

  setUp(() {
    repository = MockMenuRepository();
    when(() => repository.addDish(any())).thenAnswer((_) async => 'new1');
    when(() => repository.updateDish(any())).thenAnswer((_) async {});
    when(() => repository.deleteDish(any())).thenAnswer((_) async {});
  });

  DishFormCubit addForm() => DishFormCubit(repository, restaurantId: 'r1');

  DishFormCubit editForm() =>
      DishFormCubit(repository, restaurantId: 'r1', dish: kottu);

  void fill(
    DishFormCubit cubit, {
    String name = 'Cheese Kottu',
    String price = '1500',
    String category = 'Kottu',
  }) {
    cubit
      ..nameChanged(name)
      ..priceChanged(price)
      ..categoryChanged(category);
  }

  group('starting', () {
    test('a new form is empty, available, and shows no errors', () {
      final state = addForm().state;

      expect(state.isEditing, isFalse);
      expect(state.name, '');
      expect(state.available, isTrue);
      expect(state.showErrors, isFalse);
    });

    test('an edit form is filled from the dish', () {
      final state = editForm().state;

      expect(state.isEditing, isTrue);
      expect(state.name, 'Chicken Kottu');
      expect(state.price, '1200');
      expect(state.category, 'Kottu');
      expect(state.description, 'Spicy.');
    });
  });

  group('checks', () {
    test('an empty form has an error for name, price, and category', () {
      final state = addForm().state;

      expect(state.nameError, 'Please enter the dish name.');
      expect(state.priceError, 'Please enter the price.');
      expect(state.categoryError, 'Please enter a category.');
      expect(state.isValid, isFalse);
    });

    test('only spaces count as empty', () {
      final cubit = addForm();
      fill(cubit, name: '   ', category: '  ');

      expect(cubit.state.nameError, 'Please enter the dish name.');
      expect(cubit.state.categoryError, 'Please enter a category.');
    });

    test('a price of 0 is refused', () {
      final cubit = addForm();
      fill(cubit, price: '0');

      expect(cubit.state.priceError, 'The price must be at least 1.');
    });

    test('a price above the limit is refused', () {
      final cubit = addForm();
      fill(cubit, price: '100001');

      expect(cubit.state.priceError, 'The price is too high.');
    });

    test('a very long name is refused', () {
      final cubit = addForm();
      fill(cubit, name: 'a' * 61);

      expect(cubit.state.nameError, 'Use 60 letters or less.');
    });

    test('a filled form is valid', () {
      final cubit = addForm();
      fill(cubit);

      expect(cubit.state.isValid, isTrue);
    });
  });

  group('save', () {
    test('an empty form shows errors and saves nothing', () async {
      final cubit = addForm();

      await cubit.save();

      expect(cubit.state.showErrors, isTrue);
      expect(cubit.state.status, DishFormStatus.editing);
      verifyNever(() => repository.addDish(any()));
    });

    test('a new dish is added with spaces trimmed', () async {
      final cubit = addForm();
      fill(cubit, name: '  Cheese Kottu ', category: ' Kottu ');
      cubit
        ..descriptionChanged(' With cheese. ')
        ..availableChanged(false);

      await cubit.save();

      final saved = verify(() => repository.addDish(captureAny()))
          .captured
          .single as Dish;
      expect(saved.restaurantId, 'r1');
      expect(saved.name, 'Cheese Kottu');
      expect(saved.category, 'Kottu');
      expect(saved.description, 'With cheese.');
      expect(saved.price, 1500);
      expect(saved.available, isFalse);
      expect(saved.imageUrl, '');
      expect(cubit.state.status, DishFormStatus.saved);
      expect(cubit.state.notice, 'Cheese Kottu is added to the menu.');
    });

    test('an edited dish keeps its id and photo', () async {
      final cubit = editForm()..priceChanged('1300');

      await cubit.save();

      final saved = verify(() => repository.updateDish(captureAny()))
          .captured
          .single as Dish;
      expect(saved.id, 'd1');
      expect(saved.price, 1300);
      expect(saved.imageUrl, 'https://example.com/kottu.jpg');
      expect(cubit.state.notice, 'Chicken Kottu is saved.');
      verifyNever(() => repository.addDish(any()));
    });

    test('it shows saving while it saves, and a second tap does nothing',
        () async {
      final done = Completer<String>();
      when(() => repository.addDish(any())).thenAnswer((_) => done.future);
      final cubit = addForm();
      fill(cubit);

      final first = cubit.save();
      expect(cubit.state.status, DishFormStatus.saving);
      expect(cubit.state.isBusy, isTrue);

      await cubit.save();
      done.complete('new1');
      await first;

      verify(() => repository.addDish(any())).called(1);
      expect(cubit.state.status, DishFormStatus.saved);
    });

    test('a save error keeps the page open with the reason', () async {
      when(() => repository.addDish(any())).thenThrow(
        const DataFailure('No internet connection. Please try again.'),
      );
      final cubit = addForm();
      fill(cubit);

      await cubit.save();

      expect(cubit.state.status, DishFormStatus.editing);
      expect(
        cubit.state.notice,
        'No internet connection. Please try again.',
      );
      expect(cubit.state.noticeId, 1);
    });
  });

  group('delete', () {
    test('deletes the dish and says so', () async {
      final cubit = editForm();

      await cubit.delete();

      verify(() => repository.deleteDish(kottu)).called(1);
      expect(cubit.state.status, DishFormStatus.deleted);
      expect(cubit.state.notice, 'Chicken Kottu is deleted.');
    });

    test('does nothing on a new dish', () async {
      final cubit = addForm();

      await cubit.delete();

      verifyNever(() => repository.deleteDish(any()));
    });

    test('a delete error keeps the page open with the reason', () async {
      when(() => repository.deleteDish(any())).thenThrow(
        const DataFailure('This dish was not found.'),
      );
      final cubit = editForm();

      await cubit.delete();

      expect(cubit.state.status, DishFormStatus.editing);
      expect(cubit.state.notice, 'This dish was not found.');
    });
  });
}