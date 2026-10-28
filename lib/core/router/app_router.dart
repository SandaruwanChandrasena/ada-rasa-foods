import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../widgets/role_home_placeholder.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String signUp = '/sign-up';
  static const String customer = '/customer';
  static const String restaurant = '/restaurant';
  static const String admin = '/admin';
  static const String rider = '/rider';

  // The home path for each role (AUTH-2).
  static String homeFor(UserRole role) {
    return switch (role) {
      UserRole.customer => customer,
      UserRole.restaurant => restaurant,
      UserRole.admin => admin,
      UserRole.rider => rider,
    };
  }
}

GoRouter createRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    // Runs the redirect again every time AuthCubit changes.
    refreshListenable: _StreamListenable(authCubit.stream),
    redirect: (context, state) {
      final auth = authCubit.state;
      final location = state.matchedLocation;

      return switch (auth.status) {
        AuthStatus.unknown =>
          location == AppRoutes.splash ? null : AppRoutes.splash,
        // Signed-out users may only see sign in and sign up.
        AuthStatus.unauthenticated =>
          (location == AppRoutes.login || location == AppRoutes.signUp)
              ? null
              : AppRoutes.login,
        AuthStatus.authenticated => _homeRedirect(auth, location),
      };
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.customer,
        builder: (context, state) => const RoleHomePlaceholder(
          title: 'Customer home',
          nextStep: 'Next: restaurant list, search, and categories (CUS-1).',
        ),
      ),
      GoRoute(
        path: AppRoutes.restaurant,
        builder: (context, state) => const RoleHomePlaceholder(
          title: 'Restaurant home',
          nextStep: 'Next: orders board with New, Active, and Done (RES-1).',
        ),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const RoleHomePlaceholder(
          title: 'Admin home',
          nextStep: 'Next: dashboard with counts (ADM-1).',
        ),
      ),
      GoRoute(
        path: AppRoutes.rider,
        builder: (context, state) => const RoleHomePlaceholder(
          title: 'Rider home',
          nextStep: 'The rider app comes in Stage 2.',
        ),
      ),
    ],
  );
}

// A signed-in user can only stay inside their own role's home.
String? _homeRedirect(AuthState auth, String location) {
  final user = auth.user;
  if (user == null) return AppRoutes.login;

  final home = AppRoutes.homeFor(user.role);
  return location.startsWith(home) ? null : home;
}

// Turns the Cubit stream into a Listenable that go_router can watch.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}