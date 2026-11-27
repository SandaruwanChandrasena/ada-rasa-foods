import 'package:ada_rasa_foods/features/auth/domain/app_user.dart';
import 'package:ada_rasa_foods/features/auth/domain/user_role.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:ada_rasa_foods/features/orders/presentation/my_orders/my_orders_cubit.dart';
import 'package:ada_rasa_foods/features/orders/presentation/my_orders/my_orders_state.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/home/home_header.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

class MockMyOrdersCubit extends MockCubit<MyOrdersState>
    implements MyOrdersCubit {}

AppUser customer(String name) {
  return AppUser(
    uid: 'u1',
    name: name,
    email: 'nimal@test.com',
    role: UserRole.customer,
  );
}

FoodOrder order(String id, OrderStatus status) {
  return FoodOrder(
    id: id,
    customerId: 'u1',
    customerName: 'Nimal',
    restaurantId: 'r1',
    restaurantName: 'Kottu Corner',
    restaurantAddress: 'Colombo',
    items: const [],
    total: 1200,
    paymentMethod: PaymentMethod.cash,
    paymentStatus: PaymentStatus.pending,
    status: status,
  );
}

MyOrdersState loadedWith(
  List<FoodOrder> orders, {
  Set<String> seenIds = const {},
}) {
  return MyOrdersState(
    status: MyOrdersStatus.loaded,
    orders: orders,
    seenIds: seenIds,
  );
}

void main() {
  group('HomeGreeting.firstName', () {
    test('uses the first word of the name', () {
      expect(HomeGreeting.firstName('Nimal Perera'), 'Nimal');
    });

    test('ignores spaces around the name', () {
      expect(HomeGreeting.firstName('   Nimal   Perera '), 'Nimal');
    });

    test('an empty name says "there"', () {
      expect(HomeGreeting.firstName(''), 'there');
      expect(HomeGreeting.firstName('   '), 'there');
    });
  });

  group('HomeGreeting', () {
    late MockAuthCubit auth;

    setUp(() => auth = MockAuthCubit());

    Future<void> show(WidgetTester tester, String name) async {
      when(() => auth.state)
          .thenReturn(AuthState.authenticated(customer(name)));
      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: auth,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(centerTitle: false, title: const HomeGreeting()),
            ),
          ),
        ),
      );
    }

    testWidgets('says Hi with the first name and an orange wave', (
      tester,
    ) async {
      await show(tester, 'Nimal Perera');

      expect(find.text('Hi, Nimal'), findsOneWidget);
      expect(find.byIcon(Icons.waving_hand_rounded), findsOneWidget);
    });

    testWidgets('a very long name fits with no overflow', (tester) async {
      await show(tester, 'Wickramasinghearachchigebartholomewperera Silva');

      expect(tester.takeException(), isNull);
      expect(find.byType(HomeGreeting), findsOneWidget);
    });
  });

  group('WelcomeBanner.shownFor', () {
    test('hidden while the orders are loading', () {
      expect(WelcomeBanner.shownFor(const MyOrdersState()), isFalse);
    });

    test('shown when the orders could not load', () {
      const failed = MyOrdersState(status: MyOrdersStatus.failure);

      expect(WelcomeBanner.shownFor(failed), isTrue);
    });

    test('shown when there are no orders', () {
      expect(WelcomeBanner.shownFor(loadedWith([])), isTrue);
    });

    test('shown when every order is finished', () {
      final state = loadedWith([
        order('a', OrderStatus.completed),
        order('b', OrderStatus.cancelled),
      ]);

      expect(WelcomeBanner.shownFor(state), isTrue);
    });

    test('hidden while an order is still going', () {
      final state = loadedWith([order('a', OrderStatus.preparing)]);

      expect(WelcomeBanner.shownFor(state), isFalse);
    });

    test('hidden while a rejected order is not seen yet', () {
      final state = loadedWith([order('a', OrderStatus.rejected)]);

      expect(WelcomeBanner.shownFor(state), isFalse);
    });

    test('shown again after the rejected order is seen', () {
      final state = loadedWith(
        [order('a', OrderStatus.rejected)],
        seenIds: {'a'},
      );

      expect(WelcomeBanner.shownFor(state), isTrue);
    });
  });

  group('WelcomeBanner', () {
    late MockMyOrdersCubit orders;

    setUp(() => orders = MockMyOrdersCubit());

    Future<void> show(WidgetTester tester) async {
      await tester.pumpWidget(
        BlocProvider<MyOrdersCubit>.value(
          value: orders,
          child: const MaterialApp(home: Scaffold(body: WelcomeBanner())),
        ),
      );
    }

    testWidgets('shows the short title, line and pickup icon', (
      tester,
    ) async {
      when(() => orders.state).thenReturn(loadedWith([]));
      await show(tester);

      expect(find.text(WelcomeBanner.title), findsOneWidget);
      expect(find.text(WelcomeBanner.subtitle), findsOneWidget);
      expect(find.byIcon(Icons.takeout_dining_rounded), findsOneWidget);
    });

    testWidgets('shows nothing while an order is going', (tester) async {
      when(() => orders.state)
          .thenReturn(loadedWith([order('a', OrderStatus.ready)]));
      await show(tester);

      expect(find.text(WelcomeBanner.title), findsNothing);
    });

    testWidgets('comes back when the last order finishes', (tester) async {
      whenListen(
        orders,
        Stream.fromIterable([
          loadedWith([order('a', OrderStatus.completed)]),
        ]),
        initialState: loadedWith([order('a', OrderStatus.ready)]),
      );
      await show(tester);
      await tester.pump();

      expect(find.text(WelcomeBanner.title), findsOneWidget);
    });
  });
}