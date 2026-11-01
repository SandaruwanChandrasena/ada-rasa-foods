import 'dart:async';

import 'package:ada_rasa_foods/features/auth/domain/app_user.dart';
import 'package:ada_rasa_foods/features/auth/domain/auth_failure.dart';
import 'package:ada_rasa_foods/features/auth/domain/auth_repository.dart';
import 'package:ada_rasa_foods/features/auth/domain/user_role.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
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

const nimalWithPhone = AppUser(
  uid: 'u1',
  name: 'Nimal Perera',
  email: 'nimal@test.com',
  phone: '0712345678',
  role: UserRole.customer,
);

const loading = AuthState.unauthenticated(isLoading: true);

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    when(() => repository.signOut()).thenAnswer((_) async {});
  });

  AuthCubit build() => AuthCubit(repository);

  // A cubit that is already signed in as Nimal.
  AuthCubit signedIn() {
    when(() => repository.getCurrentUser()).thenAnswer((_) async => nimal);
    return build();
  }

  test('starts as unknown', () {
    expect(build().state, const AuthState.unknown());
  });

  group('checkSession', () {
    blocTest<AuthCubit, AuthState>(
      'a saved login opens as signed in',
      setUp: () => when(() => repository.getCurrentUser())
          .thenAnswer((_) async => nimal),
      build: build,
      act: (cubit) => cubit.checkSession(),
      expect: () => const [AuthState.authenticated(nimal)],
    );

    blocTest<AuthCubit, AuthState>(
      'no saved login opens as signed out',
      setUp: () => when(() => repository.getCurrentUser())
          .thenAnswer((_) async => null),
      build: build,
      act: (cubit) => cubit.checkSession(),
      expect: () => const [AuthState.unauthenticated()],
    );

    blocTest<AuthCubit, AuthState>(
      'an error opens as signed out, with the message',
      setUp: () => when(() => repository.getCurrentUser())
          .thenThrow(const AuthFailure('No internet connection.')),
      build: build,
      act: (cubit) => cubit.checkSession(),
      expect: () => const [
        AuthState.unauthenticated(errorMessage: 'No internet connection.'),
      ],
    );

    test('waits for the splash time, even when the check is fast',
        () async {
      when(() => repository.getCurrentUser()).thenAnswer((_) async => nimal);
      final cubit = build();

      final done = cubit.checkSession(
        minSplashTime: const Duration(milliseconds: 80),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(cubit.state, const AuthState.unknown());

      await done;
      expect(cubit.state, const AuthState.authenticated(nimal));
      await cubit.close();
    });
  });

  group('sign in', () {
    blocTest<AuthCubit, AuthState>(
      'email sign in shows loading, then signed in',
      setUp: () => when(
        () => repository.signInWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => nimal),
      build: build,
      act: (cubit) => cubit.signInWithEmail(
        email: '  nimal@test.com ',
        password: 'Rasa@2026',
      ),
      expect: () => const [loading, AuthState.authenticated(nimal)],
      verify: (_) => verify(
        () => repository.signInWithEmail(
          email: 'nimal@test.com',
          password: 'Rasa@2026',
        ),
      ).called(1),
    );

    blocTest<AuthCubit, AuthState>(
      'a wrong password shows the message',
      setUp: () => when(
        () => repository.signInWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AuthFailure('Email or password is wrong.')),
      build: build,
      act: (cubit) => cubit.signInWithEmail(
        email: 'nimal@test.com',
        password: 'wrong',
      ),
      expect: () => const [
        loading,
        AuthState.unauthenticated(
          errorMessage: 'Email or password is wrong.',
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'Google sign in works',
      setUp: () => when(() => repository.signInWithGoogle())
          .thenAnswer((_) async => nimal),
      build: build,
      act: (cubit) => cubit.signInWithGoogle(),
      expect: () => const [loading, AuthState.authenticated(nimal)],
    );

    blocTest<AuthCubit, AuthState>(
      'closing the Google picker goes back to signed out, with no error',
      setUp: () => when(() => repository.signInWithGoogle())
          .thenAnswer((_) async => null),
      build: build,
      act: (cubit) => cubit.signInWithGoogle(),
      expect: () => const [loading, AuthState.unauthenticated()],
    );

    blocTest<AuthCubit, AuthState>(
      'a fast second tap does not sign in twice',
      setUp: () {
        final slow = Completer<AppUser?>();
        when(() => repository.signInWithGoogle())
            .thenAnswer((_) => slow.future);
        Future<void>.delayed(
          const Duration(milliseconds: 20),
          () => slow.complete(nimal),
        );
      },
      build: build,
      act: (cubit) async {
        final first = cubit.signInWithGoogle();
        await cubit.signInWithGoogle();
        await first;
      },
      expect: () => const [loading, AuthState.authenticated(nimal)],
      verify: (_) => verify(() => repository.signInWithGoogle()).called(1),
    );

    blocTest<AuthCubit, AuthState>(
      'sign up trims the name and email',
      setUp: () => when(
        () => repository.registerWithEmail(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => nimal),
      build: build,
      act: (cubit) => cubit.register(
        name: ' Nimal ',
        email: ' nimal@test.com ',
        password: 'Rasa@2026',
      ),
      expect: () => const [loading, AuthState.authenticated(nimal)],
      verify: (_) => verify(
        () => repository.registerWithEmail(
          name: 'Nimal',
          email: 'nimal@test.com',
          password: 'Rasa@2026',
        ),
      ).called(1),
    );
  });

  group('signOut', () {
    blocTest<AuthCubit, AuthState>(
      'signs out',
      build: signedIn,
      act: (cubit) async {
        await cubit.checkSession();
        await cubit.signOut();
      },
      expect: () => const [
        AuthState.authenticated(nimal),
        AuthState.unauthenticated(),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'shows the login screen even if sign out fails',
      setUp: () => when(() => repository.signOut())
          .thenThrow(const AuthFailure('No internet connection.')),
      build: signedIn,
      act: (cubit) async {
        await cubit.checkSession();
        await cubit.signOut();
      },
      expect: () => const [
        AuthState.authenticated(nimal),
        AuthState.unauthenticated(),
      ],
    );
  });

  group('updateUser', () {
    blocTest<AuthCubit, AuthState>(
      'shows the new name and phone at once',
      build: signedIn,
      act: (cubit) async {
        await cubit.checkSession();
        cubit.updateUser(nimalWithPhone);
      },
      expect: () => const [
        AuthState.authenticated(nimal),
        AuthState.authenticated(nimalWithPhone),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'ignores a different user',
      build: signedIn,
      act: (cubit) async {
        await cubit.checkSession();
        cubit.updateUser(
          const AppUser(
            uid: 'someone_else',
            name: 'Kamal',
            email: 'kamal@test.com',
            role: UserRole.customer,
          ),
        );
      },
      expect: () => const [AuthState.authenticated(nimal)],
    );

    blocTest<AuthCubit, AuthState>(
      'does nothing when signed out',
      setUp: () => when(() => repository.getCurrentUser())
          .thenAnswer((_) async => null),
      build: build,
      act: (cubit) async {
        await cubit.checkSession();
        cubit.updateUser(nimalWithPhone);
      },
      expect: () => const [AuthState.unauthenticated()],
    );

    blocTest<AuthCubit, AuthState>(
      'does nothing when nothing changed',
      build: signedIn,
      act: (cubit) async {
        await cubit.checkSession();
        cubit.updateUser(nimal);
      },
      expect: () => const [AuthState.authenticated(nimal)],
    );
  });
}