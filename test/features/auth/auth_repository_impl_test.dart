import 'package:ada_rasa_foods/features/auth/data/app_user_model.dart';
import 'package:ada_rasa_foods/features/auth/data/auth_remote_data_source.dart';
import 'package:ada_rasa_foods/features/auth/data/auth_repository_impl.dart';
import 'package:ada_rasa_foods/features/auth/domain/app_user.dart';
import 'package:ada_rasa_foods/features/auth/domain/auth_failure.dart';
import 'package:ada_rasa_foods/features/auth/domain/user_role.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRemote extends Mock implements AuthRemoteDataSource {}

class MockUser extends Mock implements User {}

const nimal = AppUser(
  uid: 'u1',
  name: 'Nimal',
  email: 'nimal@test.com',
  role: UserRole.customer,
);

const nimalModel = AppUserModel(
  uid: 'u1',
  name: 'Nimal',
  email: 'nimal@test.com',
  role: UserRole.customer,
);

// Checks that [action] throws an AuthFailure with this message.
Future<void> expectFailure(
  Future<Object?> Function() action,
  String message,
) async {
  await expectLater(
    action(),
    throwsA(
      isA<AuthFailure>().having((e) => e.message, 'message', message),
    ),
  );
}

void main() {
  late MockRemote remote;
  late MockUser firebaseUser;
  late AuthRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(MockUser()));

  setUp(() {
    remote = MockRemote();
    firebaseUser = MockUser();
    repository = AuthRepositoryImpl(remote);

    when(
      () => remote.updateProfile(
        uid: any(named: 'uid'),
        name: any(named: 'name'),
        phone: any(named: 'phone'),
      ),
    ).thenAnswer((_) async {});
    when(() => remote.signOut()).thenAnswer((_) async {});
  });

  group('updateProfile', () {
    test('saves a trimmed name and a digits-only phone', () async {
      final updated = await repository.updateProfile(
        user: nimal,
        name: '  Nimal Perera ',
        phone: '071 234 5678',
      );

      verify(
        () => remote.updateProfile(
          uid: 'u1',
          name: 'Nimal Perera',
          phone: '0712345678',
        ),
      ).called(1);

      expect(updated.name, 'Nimal Perera');
      expect(updated.phone, '0712345678');
    });

    test('keeps the email, role, and restaurant the same', () async {
      const owner = AppUser(
        uid: 'o1',
        name: 'Owner',
        email: 'owner1@adarasa.test',
        role: UserRole.restaurant,
        restaurantId: 'restaurant_1',
      );

      final updated = await repository.updateProfile(
        user: owner,
        name: 'Owner One',
        phone: '0771234567',
      );

      expect(updated.uid, 'o1');
      expect(updated.email, 'owner1@adarasa.test');
      expect(updated.role, UserRole.restaurant);
      expect(updated.restaurantId, 'restaurant_1');
    });

    test('an empty name is refused and nothing is saved', () async {
      await expectFailure(
        () => repository.updateProfile(
          user: nimal,
          name: '   ',
          phone: '0712345678',
        ),
        'Please enter your name.',
      );
      verifyNever(
        () => remote.updateProfile(
          uid: any(named: 'uid'),
          name: any(named: 'name'),
          phone: any(named: 'phone'),
        ),
      );
    });

    test('a wrong phone is refused and nothing is saved', () async {
      await expectFailure(
        () => repository.updateProfile(
          user: nimal,
          name: 'Nimal',
          phone: '011 234 5678',
        ),
        'A mobile number starts with 07.',
      );
      verifyNever(
        () => remote.updateProfile(
          uid: any(named: 'uid'),
          name: any(named: 'name'),
          phone: any(named: 'phone'),
        ),
      );
    });

    test('a rules error gives a clear message', () async {
      when(
        () => remote.updateProfile(
          uid: any(named: 'uid'),
          name: any(named: 'name'),
          phone: any(named: 'phone'),
        ),
      ).thenThrow(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );

      await expectFailure(
        () => repository.updateProfile(
          user: nimal,
          name: 'Nimal',
          phone: '0712345678',
        ),
        'The database blocked this request. Check the Firestore rules.',
      );
    });

    test('no internet gives a clear message', () async {
      when(
        () => remote.updateProfile(
          uid: any(named: 'uid'),
          name: any(named: 'name'),
          phone: any(named: 'phone'),
        ),
      ).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );

      await expectFailure(
        () => repository.updateProfile(
          user: nimal,
          name: 'Nimal',
          phone: '0712345678',
        ),
        'No internet connection. Please try again.',
      );
    });
  });

  group('isGoogleUser', () {
    test('passes on the answer from Firebase', () {
      when(() => remote.isGoogleUser).thenReturn(true);
      expect(repository.isGoogleUser, isTrue);

      when(() => remote.isGoogleUser).thenReturn(false);
      expect(repository.isGoogleUser, isFalse);
    });
  });

  group('sign in', () {
    test('getCurrentUser gives null when nobody is signed in', () async {
      when(() => remote.currentUser).thenReturn(null);
      expect(await repository.getCurrentUser(), isNull);
    });

    test('email sign in gives the profile', () async {
      when(
        () => remote.signInWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => firebaseUser);
      when(
        () => remote.getOrCreateProfile(any(), name: any(named: 'name')),
      ).thenAnswer((_) async => nimalModel);

      final user = await repository.signInWithEmail(
        email: 'nimal@test.com',
        password: 'Rasa@2026',
      );

      expect(user, nimal);
    });

    test('a wrong password gives a simple message', () async {
      when(
        () => remote.signInWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'invalid-credential'));

      await expectFailure(
        () => repository.signInWithEmail(
          email: 'nimal@test.com',
          password: 'wrong',
        ),
        'Email or password is wrong.',
      );
    });

    test('if the profile fails to load, it signs out', () async {
      when(
        () => remote.signInWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => firebaseUser);
      when(
        () => remote.getOrCreateProfile(any(), name: any(named: 'name')),
      ).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );

      await expectFailure(
        () => repository.signInWithEmail(
          email: 'nimal@test.com',
          password: 'Rasa@2026',
        ),
        'No internet connection. Please try again.',
      );
      verify(() => remote.signOut()).called(1);
    });

    test('password reset trims the email', () async {
      when(() => remote.sendPasswordReset(any()))
          .thenAnswer((_) async {});

      await repository.sendPasswordReset('  nimal@test.com ');

      verify(() => remote.sendPasswordReset('nimal@test.com')).called(1);
    });
  });
}