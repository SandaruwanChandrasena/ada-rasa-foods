import 'package:ada_rasa_foods/core/router/app_router.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

String pathOf(RouteMatchBase match) => (match.route as GoRoute).path;

void main() {
  late GoRouter router;

  setUp(() {
    final auth = MockAuthCubit();
    when(() => auth.state).thenReturn(const AuthState.unknown());
    router = createRouter(auth);
  });

  tearDown(() => router.dispose());

  StatefulShellRoute customerShell() {
    return router.configuration.routes.whereType<StatefulShellRoute>().single;
  }

  List<GoRoute> tabRoutes() => [
        for (final branch in customerShell().branches)
          branch.routes.single as GoRoute,
      ];

  // The pages Flutter would show for this link, from bottom to top.
  List<RouteMatchBase> pagesFor(String location) {
    return router.configuration.findMatch(Uri.parse(location)).matches;
  }

  group('customer tabs', () {
    test('the tabs are Home, Orders and Profile, in that order', () {
      expect(tabRoutes().map((route) => route.path), [
        AppRoutes.customer,
        AppRoutes.myOrders,
        AppRoutes.profile,
      ]);
    });

    test('the tabs themselves stay inside the shell', () {
      for (final tab in tabRoutes()) {
        expect(tab.parentNavigatorKey, isNull);
      }
    });

    test('every page inside a tab opens on top, with no bar', () {
      final rootKey = router.configuration.navigatorKey;

      void check(List<RouteBase> routes) {
        for (final route in routes.cast<GoRoute>()) {
          expect(route.parentNavigatorKey, rootKey, reason: route.path);
          check(route.routes);
        }
      }

      for (final tab in tabRoutes()) {
        check(tab.routes);
      }
    });

    test('the Orders tab opens with nothing on top', () {
      final pages = pagesFor(AppRoutes.myOrders);

      expect(pages, hasLength(1));
      final shell = pages.single as ShellRouteMatch;
      expect(pathOf(shell.matches.single), AppRoutes.myOrders);
    });
  });

  // The bug: after placing an order there was no back button,
  // because nothing was under the order page.
  group('Home stays under pages opened with go()', () {
    test('order status has the Home tab under it', () {
      final pages = pagesFor(AppRoutes.orderStatus('o1'));

      expect(pages, hasLength(2));
      final shell = pages.first as ShellRouteMatch;
      expect(pathOf(shell.matches.single), AppRoutes.customer);
      expect(pathOf(pages.last), 'order/:id');
    });

    test('the cart has the Home tab under it', () {
      final pages = pagesFor(AppRoutes.cart);

      expect(pages, hasLength(2));
      expect(pages.first, isA<ShellRouteMatch>());
      expect(pathOf(pages.last), 'cart');
    });

    test('dish details has Home and its restaurant under it', () {
      final pages = pagesFor(AppRoutes.dishDetails('r1', 'd1'));

      expect(pages, hasLength(3));
      expect(pages.first, isA<ShellRouteMatch>());
      expect(pathOf(pages[1]), 'restaurant/:id');
      expect(pathOf(pages.last), 'dish/:dishId');
    });

    test('checkout, My cards and Add card have Home under them', () {
      for (final location in [
        AppRoutes.checkout,
        AppRoutes.myCards,
        AppRoutes.addCard,
      ]) {
        final pages = pagesFor(location);

        expect(pages.first, isA<ShellRouteMatch>(), reason: location);
        expect(pages, hasLength(2), reason: location);
      }
    });

    test('Settings and Edit profile have the Profile tab under them', () {
      for (final location in [AppRoutes.settings, AppRoutes.addPhone]) {
        final pages = pagesFor(location);
        final shell = pages.first as ShellRouteMatch;

        expect(pathOf(shell.matches.single), AppRoutes.profile);
        expect(pages, hasLength(2), reason: location);
      }
    });
  });

  group('links and other roles', () {
    test('the page links did not change', () {
      expect(AppRoutes.restaurantPage('r1'), '/customer/restaurant/r1');
      expect(AppRoutes.orderStatus('o1'), '/customer/order/o1');
      expect(AppRoutes.cart, '/customer/cart');
      expect(AppRoutes.settings, '/customer/profile/settings');
    });

    test('owner, admin and rider homes are not inside the shell', () {
      for (final location in [
        AppRoutes.restaurant,
        AppRoutes.admin,
        AppRoutes.rider,
      ]) {
        final pages = pagesFor(location);

        expect(pages, hasLength(1), reason: location);
        expect(pages.single, isNot(isA<ShellRouteMatch>()), reason: location);
      }
    });
  });
}