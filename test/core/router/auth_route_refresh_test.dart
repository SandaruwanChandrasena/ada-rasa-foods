import 'dart:async';

import 'package:ada_rasa_foods/core/router/app_router.dart';
import 'package:ada_rasa_foods/features/auth/domain/app_user.dart';
import 'package:ada_rasa_foods/features/auth/domain/user_role.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

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

const nimalAsOwner = AppUser(
  uid: 'u1',
  name: 'Nimal',
  email: 'nimal@test.com',
  role: UserRole.restaurant,
);

void main() {
  group('authRouteKey', () {
    test('a new name or phone gives the same key', () {
      expect(
        authRouteKey(const AuthState.authenticated(nimal)),
        authRouteKey(const AuthState.authenticated(nimalWithPhone)),
      );
    });

    test('sign out gives a different key', () {
      expect(
        authRouteKey(const AuthState.authenticated(nimal)),
        isNot(authRouteKey(const AuthState.unauthenticated())),
      );
    });

    test('a role change gives a different key', () {
      expect(
        authRouteKey(const AuthState.authenticated(nimal)),
        isNot(authRouteKey(const AuthState.authenticated(nimalAsOwner))),
      );
    });

    test('loading and errors on the sign in page give the same key', () {
      expect(
        authRouteKey(const AuthState.unauthenticated(isLoading: true)),
        authRouteKey(
          const AuthState.unauthenticated(errorMessage: 'Wrong password.'),
        ),
      );
    });
  });

  group('AuthRouteRefresh', () {
    late StreamController<AuthState> states;
    late AuthRouteRefresh refresh;
    late int wakeUps;

    setUp(() {
      states = StreamController<AuthState>();
      refresh = AuthRouteRefresh(states.stream);
      wakeUps = 0;
      refresh.addListener(() => wakeUps++);
    });

    tearDown(() async {
      refresh.dispose();
      await states.close();
    });

    // Gives the stream time to deliver.
    Future<void> send(AuthState state) async {
      states.add(state);
      await Future<void>.delayed(Duration.zero);
    }

    test('wakes the router on sign in', () async {
      await send(const AuthState.authenticated(nimal));
      expect(wakeUps, 1);
    });

    test('does not wake the router for a new name or phone', () async {
      await send(const AuthState.authenticated(nimal));
      await send(const AuthState.authenticated(nimalWithPhone));

      // Only the sign in woke it.
      expect(wakeUps, 1);
    });

    test('wakes the router on sign out and on a role change', () async {
      await send(const AuthState.authenticated(nimal));
      await send(const AuthState.authenticated(nimalAsOwner));
      await send(const AuthState.unauthenticated());

      expect(wakeUps, 3);
    });

    test('stops listening after dispose', () async {
      final other = StreamController<AuthState>();
      final router = AuthRouteRefresh(other.stream);
      var count = 0;
      router.addListener(() => count++);

      router.dispose();
      other.add(const AuthState.authenticated(nimal));
      await Future<void>.delayed(Duration.zero);

      expect(count, 0);
      await other.close();
    });
  });
}