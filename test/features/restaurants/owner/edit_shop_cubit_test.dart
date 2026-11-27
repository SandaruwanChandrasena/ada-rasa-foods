import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant_repository.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/owner/edit_shop_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRestaurantRepository extends Mock implements RestaurantRepository {}

const kottu = Restaurant(
  id: 'r1',
  name: 'Kottu Corner',
  cuisine: 'Sri Lankan',
  ownerId: 'o1',
  address: 'Colombo',
  latitude: 6.9,
  longitude: 79.8,
);

const kottuWithPhone = Restaurant(
  id: 'r1',
  name: 'Kottu Corner',
  cuisine: 'Sri Lankan',
  ownerId: 'o1',
  address: 'Colombo',
  latitude: 6.9,
  longitude: 79.8,
  phone: '0712345678',
  description: 'Best kottu in town.',
);

void main() {
  late MockRestaurantRepository repository;

  setUp(() {
    repository = MockRestaurantRepository();
    when(
      () => repository.updateDetails(
        any(),
        name: any(named: 'name'),
        cuisine: any(named: 'cuisine'),
        phone: any(named: 'phone'),
        description: any(named: 'description'),
      ),
    ).thenAnswer((_) async {});
  });

  void verifyNoSave() {
    verifyNever(
      () => repository.updateDetails(
        any(),
        name: any(named: 'name'),
        cuisine: any(named: 'cuisine'),
        phone: any(named: 'phone'),
        description: any(named: 'description'),
      ),
    );
  }

  group('start', () {
    test('starts with the shop as it is now', () {
      final cubit = EditShopCubit(repository, kottu);

      expect(cubit.state.name, 'Kottu Corner');
      expect(cubit.state.cuisine, 'Sri Lankan');
      expect(cubit.state.phone, '');
      expect(cubit.state.description, '');
      expect(cubit.state.status, EditShopStatus.editing);
      expect(cubit.state.showErrors, isFalse);
      cubit.close();
    });

    test('shows a saved phone in groups', () {
      final cubit = EditShopCubit(repository, kottuWithPhone);

      expect(cubit.state.phone, '071 234 5678');
      expect(cubit.state.description, 'Best kottu in town.');
      expect(cubit.state.hasChanges, isFalse);
      cubit.close();
    });
  });

  group('checks', () {
    EditShopState state({
      String name = 'Kottu Corner',
      String cuisine = 'Sri Lankan',
      String phone = '',
      String description = '',
      Restaurant original = kottu,
    }) {
      return EditShopState.from(original).copyWith(
        name: name,
        cuisine: cuisine,
        phone: phone,
        description: description,
      );
    }

    test('an empty name is an error', () {
      expect(state(name: '  ').nameError, 'Please enter the shop name.');
    });

    test('a new name over 40 letters is an error', () {
      expect(
        state(name: 'K' * 41).nameError,
        'Use 40 letters or fewer.',
      );
      expect(state(name: 'K' * 40).nameError, isNull);
    });

    test('an old long name that did not change is fine', () {
      final longName = 'L' * 45;
      final old = Restaurant(
        id: 'r1',
        name: longName,
        cuisine: 'Sri Lankan',
        ownerId: 'o1',
        address: 'Colombo',
        latitude: 6.9,
        longitude: 79.8,
      );

      expect(state(name: longName, original: old).nameError, isNull);
    });

    test('an empty cuisine is an error', () {
      expect(state(cuisine: '').cuisineError, 'Please enter the cuisine.');
    });

    test('a new cuisine over 20 letters is an error', () {
      expect(
        state(cuisine: 'C' * 21).cuisineError,
        'Use 20 letters or fewer.',
      );
      expect(state(cuisine: 'C' * 20).cuisineError, isNull);
    });

    test('an empty phone is fine', () {
      expect(state(phone: '  ').phoneError, isNull);
    });

    test('a wrong phone is an error', () {
      expect(
        state(phone: '0112345678').phoneError,
        'A mobile number starts with 07.',
      );
      expect(
        state(phone: '071 234').phoneError,
        'A mobile number has 10 digits.',
      );
    });

    test('a good phone with spaces is fine and saves as digits', () {
      final value = state(phone: '071 234 5678');

      expect(value.phoneError, isNull);
      expect(value.phoneDigits, '0712345678');
    });

    test('a description over 150 letters is an error', () {
      expect(
        state(description: 'd' * 151).descriptionError,
        'Use 150 letters or fewer.',
      );
      expect(state(description: 'd' * 150).descriptionError, isNull);
    });

    test('hasChanges ignores spaces and phone groups', () {
      final same = EditShopState.from(kottuWithPhone).copyWith(
        name: ' Kottu Corner ',
        phone: '0712345678',
      );

      expect(same.hasChanges, isFalse);
      expect(same.copyWith(cuisine: 'Chinese').hasChanges, isTrue);
    });
  });

  group('save', () {
    blocTest<EditShopCubit, EditShopState>(
      'a wrong form shows the errors and saves nothing',
      build: () => EditShopCubit(repository, kottu),
      act: (cubit) async {
        cubit.nameChanged('');
        await cubit.save();
      },
      verify: (cubit) {
        expect(cubit.state.showErrors, isTrue);
        expect(cubit.state.status, EditShopStatus.editing);
        verifyNoSave();
      },
    );

    blocTest<EditShopCubit, EditShopState>(
      'no changes: closes with no write and no message',
      build: () => EditShopCubit(repository, kottu),
      act: (cubit) => cubit.save(),
      verify: (cubit) {
        expect(cubit.state.status, EditShopStatus.saved);
        expect(cubit.state.notice, isNull);
        verifyNoSave();
      },
    );

    blocTest<EditShopCubit, EditShopState>(
      'saves the details, with the phone as digits',
      build: () => EditShopCubit(repository, kottu),
      act: (cubit) async {
        cubit.nameChanged('Kottu Corner Plus');
        cubit.cuisineChanged('Sri Lankan');
        cubit.phoneChanged('071 234 5678');
        cubit.descriptionChanged('Best kottu in town.');
        await cubit.save();
      },
      verify: (cubit) {
        verify(
          () => repository.updateDetails(
            'r1',
            name: 'Kottu Corner Plus',
            cuisine: 'Sri Lankan',
            phone: '0712345678',
            description: 'Best kottu in town.',
          ),
        ).called(1);
        expect(cubit.state.status, EditShopStatus.saved);
        expect(cubit.state.notice, 'Shop details are saved.');
        expect(cubit.state.noticeId, 1);
      },
    );

    blocTest<EditShopCubit, EditShopState>(
      'clearing the phone saves it as empty',
      build: () => EditShopCubit(repository, kottuWithPhone),
      act: (cubit) async {
        cubit.phoneChanged('');
        await cubit.save();
      },
      verify: (cubit) {
        verify(
          () => repository.updateDetails(
            'r1',
            name: 'Kottu Corner',
            cuisine: 'Sri Lankan',
            phone: '',
            description: 'Best kottu in town.',
          ),
        ).called(1);
      },
    );

    test('shows saving while it waits', () async {
      final done = Completer<void>();
      when(
        () => repository.updateDetails(
          any(),
          name: any(named: 'name'),
          cuisine: any(named: 'cuisine'),
          phone: any(named: 'phone'),
          description: any(named: 'description'),
        ),
      ).thenAnswer((_) => done.future);
      final cubit = EditShopCubit(repository, kottu);
      cubit.nameChanged('New Name');

      final saving = cubit.save();
      expect(cubit.state.status, EditShopStatus.saving);
      expect(cubit.state.isSaving, isTrue);

      done.complete();
      await saving;
      expect(cubit.state.status, EditShopStatus.saved);
      await cubit.close();
    });

    blocTest<EditShopCubit, EditShopState>(
      'a save error keeps the page and shows the reason',
      setUp: () {
        when(
          () => repository.updateDetails(
            any(),
            name: any(named: 'name'),
            cuisine: any(named: 'cuisine'),
            phone: any(named: 'phone'),
            description: any(named: 'description'),
          ),
        ).thenThrow(
          const DataFailure('No internet connection. Please try again.'),
        );
      },
      build: () => EditShopCubit(repository, kottu),
      act: (cubit) async {
        cubit.nameChanged('New Name');
        await cubit.save();
      },
      verify: (cubit) {
        expect(cubit.state.status, EditShopStatus.editing);
        expect(
          cubit.state.notice,
          'No internet connection. Please try again.',
        );
        expect(cubit.state.name, 'New Name');
      },
    );

    blocTest<EditShopCubit, EditShopState>(
      'an unknown error shows a simple message',
      setUp: () {
        when(
          () => repository.updateDetails(
            any(),
            name: any(named: 'name'),
            cuisine: any(named: 'cuisine'),
            phone: any(named: 'phone'),
            description: any(named: 'description'),
          ),
        ).thenThrow(Exception('boom'));
      },
      build: () => EditShopCubit(repository, kottu),
      act: (cubit) async {
        cubit.nameChanged('New Name');
        await cubit.save();
      },
      verify: (cubit) {
        expect(
          cubit.state.notice,
          'Something went wrong. Please try again.',
        );
      },
    );

    blocTest<EditShopCubit, EditShopState>(
      'a second tap while saving does not save twice',
      build: () => EditShopCubit(repository, kottu),
      act: (cubit) async {
        cubit.nameChanged('New Name');
        final first = cubit.save();
        await cubit.save();
        await first;
      },
      verify: (cubit) {
        verify(
          () => repository.updateDetails(
            any(),
            name: any(named: 'name'),
            cuisine: any(named: 'cuisine'),
            phone: any(named: 'phone'),
            description: any(named: 'description'),
          ),
        ).called(1);
      },
    );
  });
}