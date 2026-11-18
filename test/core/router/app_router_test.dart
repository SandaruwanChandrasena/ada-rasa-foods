import 'package:ada_rasa_foods/core/router/app_router.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

// Every GoRoute path inside these routes, with nested routes too.
List<String> pathsIn(List<RouteBase> routes) {
  return [
    for (final route in routes) ...[
      if (route is GoRoute) route.path,
      // A shell lists its tab routes again in route.routes, so skip them.
      if (route is StatefulShellRoute)
        for (final branch in route.branches) ...pathsIn(branch.routes)
      else
        ...pathsIn(route.routes),
    ],
  ];
}

void main() {
  late GoRouter router;

  setUp(() {
    final auth = MockAuthCubit();
    when(() => auth.state).thenReturn(const AuthState.unknown());
    router = createRouter(auth);
  });

  tearDown(() => router.dispose());

  List<RouteBase> topRoutes() => router.configuration.routes;

  StatefulShellRoute customerShell() {
    return topRoutes().whereType<StatefulShellRoute>().single;
  }

  group('customer tabs', () {
    test('there is one shell with 3 tabs', () {
      expect(customerShell().branches, hasLength(3));
    });

    test('the tabs are Home, Orders and Profile, in that order', () {
      final tabPaths = [
        for (final branch in customerShell().branches)
          (branch.routes.single as GoRoute).path,
      ];

      expect(tabPaths, [
        AppRoutes.customer,
        AppRoutes.myOrders,
        AppRoutes.profile,
      ]);
    });

    test('the tabs have no pages inside them', () {
      // Pages inside a tab would show the bottom bar.
      expect(pathsIn([customerShell()]), [
        AppRoutes.customer,
        AppRoutes.myOrders,
        AppRoutes.profile,
      ]);
    });
  });

  group('pages with no bottom bar', () {
    test('open on top of the tabs, outside the shell', () {
      final topPaths = [
        for (final route in topRoutes())
          if (route is GoRoute) route.path,
      ];

      expect(
        topPaths,
        containsAll([
          '${AppRoutes.customer}/restaurant/:id',
          AppRoutes.cart,
          AppRoutes.checkout,
          '${AppRoutes.customer}/order/:id',
          AppRoutes.myCards,
          AppRoutes.addCard,
          AppRoutes.settings,
          AppRoutes.editProfile,
        ]),
      );
    });

    test('dish details is still under its restaurant page', () {
      final restaurantPage = topRoutes().whereType<GoRoute>().singleWhere(
            (route) => route.path == '${AppRoutes.customer}/restaurant/:id',
          );
      final dish = restaurantPage.routes.single as GoRoute;

      expect(dish.path, 'dish/:dishId');
    });

    test('the page links still match the routes', () {
      expect(AppRoutes.restaurantPage('r1'), '/customer/restaurant/r1');
      expect(
        AppRoutes.dishDetails('r1', 'd1'),
        '/customer/restaurant/r1/dish/d1',
      );
      expect(AppRoutes.orderStatus('o1'), '/customer/order/o1');
      expect(AppRoutes.myOrders, '/customer/orders');
      expect(AppRoutes.profile, '/customer/profile');
    });
  });

  group('other roles', () {
    test('owner, admin and rider homes are not inside the shell', () {
      final topPaths = [
        for (final route in topRoutes())
          if (route is GoRoute) route.path,
      ];

      expect(
        topPaths,
        containsAll([AppRoutes.restaurant, AppRoutes.admin, AppRoutes.rider]),
      );
      expect(pathsIn([customerShell()]), isNot(contains(AppRoutes.restaurant)));
    });
  });
}