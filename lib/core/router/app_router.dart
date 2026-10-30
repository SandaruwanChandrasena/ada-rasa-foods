import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/orders/presentation/checkout_screen.dart';
import '../../features/orders/presentation/order_status_screen.dart';
import '../../features/restaurants/presentation/customer_home_screen.dart';
import '../../features/restaurants/presentation/restaurant_page.dart';
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

  // Restaurant page inside the customer area (CUS-2).
  static String restaurantPage(String restaurantId) =>
      '$customer/restaurant/$restaurantId';

  // Cart screen inside the customer area (CUS-3).
  static const String cart = '$customer/cart';

  // Checkout screen inside the customer area (CUS-4).
  static const String checkout = '$customer/checkout';

  // Order status screen inside the customer area (CUS-11).
  static String orderStatus(String orderId) => '$customer/order/$orderId';

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
        builder: (context, state) => const CustomerHomeScreen(),
        routes: [
          GoRoute(
            path: 'restaurant/:id',
            builder: (context, state) =>
                RestaurantPage(restaurantId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'cart',
            builder: (context, state) => const CartScreen(),
          ),
          GoRoute(
            path: 'checkout',
            builder: (context, state) => const CheckoutScreen(),
          ),
          GoRoute(
            path: 'order/:id',
            builder: (context, state) =>
                OrderStatusScreen(orderId: state.pathParameters['id']!),
          ),
        ],
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