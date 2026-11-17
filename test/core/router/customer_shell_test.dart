import 'package:ada_rasa_foods/core/router/customer_shell.dart';
import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/customer_bottom_bar.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:ada_rasa_foods/features/orders/presentation/my_orders_cubit.dart';
import 'package:ada_rasa_foods/features/orders/presentation/my_orders_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockMyOrdersCubit extends MockCubit<MyOrdersState>
    implements MyOrdersCubit {}

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

MyOrdersState loadedWith(List<FoodOrder> orders) {
  return MyOrdersState(status: MyOrdersStatus.loaded, orders: orders);
}

void main() {
  late MockMyOrdersCubit orders;
  late List<int> taps;

  setUp(() {
    orders = MockMyOrdersCubit();
    taps = [];
  });

  Future<void> show(
    WidgetTester tester, {
    int currentIndex = CustomerBottomBar.home,
    MyOrdersState state = const MyOrdersState(),
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    when(() => orders.state).thenReturn(state);

    await tester.pumpWidget(
      BlocProvider<MyOrdersCubit>.value(
        value: orders,
        child: MaterialApp(
          builder: (context, child) => AppThemeByWidth(child: child!),
          home: CustomerShell(
            currentIndex: currentIndex,
            onTabSelected: taps.add,
            child: const Center(child: Text('Tab page')),
          ),
        ),
      ),
    );
  }

  Badge ordersBadge(WidgetTester tester) {
    return tester.widget<Badge>(
      find.ancestor(
        of: find.byIcon(Icons.receipt_long_rounded),
        matching: find.byType(Badge),
      ),
    );
  }

  int selectedTab(WidgetTester tester) {
    return tester.widget<NavigationBar>(find.byType(NavigationBar))
        .selectedIndex;
  }

  group('CustomerShell', () {
    testWidgets('shows the tab page and the bottom bar', (tester) async {
      await show(tester);

      expect(find.text('Tab page'), findsOneWidget);
      expect(find.byType(CustomerBottomBar), findsOneWidget);
      expect(selectedTab(tester), CustomerBottomBar.home);
    });

    testWidgets('the bar shows the open tab', (tester) async {
      await show(tester, currentIndex: CustomerBottomBar.profile);

      expect(selectedTab(tester), CustomerBottomBar.profile);
    });

    testWidgets('tapping a tab tells the router', (tester) async {
      await show(tester);

      await tester.tap(find.text('Orders'));
      await tester.pump();

      expect(taps, [CustomerBottomBar.orders]);
    });

    testWidgets('no dot while the orders are loading', (tester) async {
      await show(tester);

      expect(ordersBadge(tester).isLabelVisible, isFalse);
    });

    testWidgets('a dot when an order is still going', (tester) async {
      await show(
        tester,
        state: loadedWith([
          order('a', OrderStatus.completed),
          order('b', OrderStatus.preparing),
        ]),
      );

      expect(ordersBadge(tester).isLabelVisible, isTrue);
    });

    testWidgets('a Ready for pickup order still shows the dot', (
      tester,
    ) async {
      await show(tester, state: loadedWith([order('a', OrderStatus.ready)]));

      expect(ordersBadge(tester).isLabelVisible, isTrue);
    });

    testWidgets('no dot when every order is finished', (tester) async {
      await show(
        tester,
        state: loadedWith([
          order('a', OrderStatus.completed),
          order('b', OrderStatus.rejected),
          order('c', OrderStatus.cancelled),
        ]),
      );

      expect(ordersBadge(tester).isLabelVisible, isFalse);
    });

    testWidgets('the dot goes away when the last order finishes', (
      tester,
    ) async {
      whenListen(
        orders,
        Stream.fromIterable([
          loadedWith([order('a', OrderStatus.completed)]),
        ]),
        initialState: loadedWith([order('a', OrderStatus.ready)]),
      );
      await tester.pumpWidget(
        BlocProvider<MyOrdersCubit>.value(
          value: orders,
          child: MaterialApp(
            home: CustomerShell(
              currentIndex: CustomerBottomBar.home,
              onTabSelected: taps.add,
              child: const Text('Tab page'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(ordersBadge(tester).isLabelVisible, isFalse);
    });

    testWidgets('phone back on Orders goes to Home', (tester) async {
      await show(tester, currentIndex: CustomerBottomBar.orders);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(taps, [CustomerBottomBar.home]);
      expect(find.text('Tab page'), findsOneWidget);
    });

    testWidgets('phone back on Profile goes to Home', (tester) async {
      await show(tester, currentIndex: CustomerBottomBar.profile);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(taps, [CustomerBottomBar.home]);
    });

    testWidgets('phone back on Home does not change the tab', (tester) async {
      await show(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(taps, isEmpty);
    });

    testWidgets('the frame leaves the keyboard to each tab page', (
      tester,
    ) async {
      await show(tester);

      final frame = tester.widget<Scaffold>(
        find.ancestor(
          of: find.byType(CustomerBottomBar),
          matching: find.byType(Scaffold),
        ),
      );
      expect(frame.resizeToAvoidBottomInset, isFalse);
    });
  });
}