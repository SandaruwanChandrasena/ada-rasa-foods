import 'dart:async';

import 'package:ada_rasa_foods/features/auth/domain/app_user.dart';
import 'package:ada_rasa_foods/features/auth/domain/auth_failure.dart';
import 'package:ada_rasa_foods/features/auth/domain/auth_repository.dart';
import 'package:ada_rasa_foods/features/auth/domain/user_role.dart';
import 'package:ada_rasa_foods/features/profile/presentation/edit_profile_cubit.dart';
import 'package:ada_rasa_foods/features/profile/presentation/edit_profile_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const nimal = AppUser(
  uid: 'u1',
  name: 'Nimal',
  email: 'nimal@test.com',
  role: UserRole.customer,
);

const updated = AppUser(
  uid: 'u1',
  name: 'Nimal Perera',
  email: 'nimal@test.com',
  phone: '0712345678',
  role: UserRole.customer,
);

const saving = EditProfileState(status: EditProfileStatus.saving);
const saved = EditProfileState(
  status: EditProfileStatus.saved,
  user: updated,
);

void main() {
  late MockAuthRepository repository;

  setUpAll(() => registerFallbackValue(nimal));

  setUp(() {
    repository = MockAuthRepository();
    when(
      () => repository.updateProfile(
        user: any(named: 'user'),
        name: any(named: 'name'),
        phone: any(named: 'phone'),
      ),
    ).thenAnswer((_) async => updated);
  });

  EditProfileCubit build() => EditProfileCubit(repository);

  Future<void> save(EditProfileCubit cubit) => cubit.save(
        user: nimal,
        name: 'Nimal Perera',
        phone: '071 234 5678',
      );

  test('starts as editing', () {
    expect(build().state, const EditProfileState());
  });

  blocTest<EditProfileCubit, EditProfileState>(
    'a good save goes saving, then saved with the new user',
    build: build,
    act: save,
    expect: () => const [saving, saved],
    verify: (_) => verify(
      () => repository.updateProfile(
        user: nimal,
        name: 'Nimal Perera',
        phone: '071 234 5678',
      ),
    ).called(1),
  );

  blocTest<EditProfileCubit, EditProfileState>(
    'an error shows its message',
    setUp: () => when(
      () => repository.updateProfile(
        user: any(named: 'user'),
        name: any(named: 'name'),
        phone: any(named: 'phone'),
      ),
    ).thenThrow(
      const AuthFailure('No internet connection. Please try again.'),
    ),
    build: build,
    act: save,
    expect: () => const [
      saving,
      EditProfileState(
        status: EditProfileStatus.failure,
        errorMessage: 'No internet connection. Please try again.',
      ),
    ],
  );

  blocTest<EditProfileCubit, EditProfileState>(
    'can save again after an error',
    setUp: () {
      var calls = 0;
      when(
        () => repository.updateProfile(
          user: any(named: 'user'),
          name: any(named: 'name'),
          phone: any(named: 'phone'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw const AuthFailure('No internet connection.');
        return updated;
      });
    },
    build: build,
    act: (cubit) async {
      await save(cubit);
      await save(cubit);
    },
    expect: () => const [
      saving,
      EditProfileState(
        status: EditProfileStatus.failure,
        errorMessage: 'No internet connection.',
      ),
      saving,
      saved,
    ],
  );

  blocTest<EditProfileCubit, EditProfileState>(
    'a fast second tap saves only once',
    setUp: () {
      final slow = Completer<AppUser>();
      when(
        () => repository.updateProfile(
          user: any(named: 'user'),
          name: any(named: 'name'),
          phone: any(named: 'phone'),
        ),
      ).thenAnswer((_) => slow.future);
      Future<void>.delayed(
        const Duration(milliseconds: 20),
        () => slow.complete(updated),
      );
    },
    build: build,
    act: (cubit) async {
      final first = save(cubit);
      await save(cubit);
      await first;
    },
    expect: () => const [saving, saved],
    verify: (_) => verify(
      () => repository.updateProfile(
        user: any(named: 'user'),
        name: any(named: 'name'),
        phone: any(named: 'phone'),
      ),
    ).called(1),
  );

  blocTest<EditProfileCubit, EditProfileState>(
    'a tap after saving does nothing',
    build: build,
    act: (cubit) async {
      await save(cubit);
      await save(cubit);
    },
    expect: () => const [saving, saved],
  );
}