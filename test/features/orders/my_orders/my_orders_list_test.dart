import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_item.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:ada_rasa_foods/features/orders/presentation/my_orders/my_orders_list.dart';
import 'package:ada_rasa_foods/features/orders/presentation/my_orders/my_orders_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const kottu = OrderItem(
  dishId: 'd1',
  name: 'Chicken Kottu',
  price: 1250,
  quantity: 2,
);
const tea = OrderItem(dishId: 'd2', name: 'Tea', price: 150, quantity: 1);

FoodOrder orderWith(
  String id,
  OrderStatus status, {
  String restaurantName = 'Kottu Corner',
  List<OrderItem> items = const [kottu, tea],
}) {
  return FoodOrder(
    id: id,
    customerId: 'u1',
    customerName: 'Nimal',
    restaurantId: 'r1',
    restaurantName: restaurantName,
    restaurantAddress: '12 Galle Road, Colombo 03',
    items: items,
    total: 2650,
    paymentMethod: PaymentMethod.cash,
    paymentStatus: PaymentStatus.pending,
    status: status,
    placedAt: DateTime(2026, 11, 25, 14, 28),
  );
}

MyOrdersState loaded(List<FoodOrder> orders) =>
    MyOrdersState(status: MyOrdersStatus.loaded, orders: orders);

// The colours of the status pill inside one order row.
(Color, Color) pillColors(WidgetTester tester, String orderId) {
  final pill = find.descendant(
    of: find.byKey(ValueKey('order_$orderId')),
    matching: find.byType(OrderStatusPill),
  );
  final box = tester.widget<Container>(
    find.descendant(of: pill, matching: find.byType(Container)).first,
  );
  final text = tester.widget<Text>(
    find.descendant(of: pill, matching: find.byType(Text)),
  );
  return (text.style!.color!, (box.decoration! as BoxDecoration).color!);
}

void main() {
  late List<FoodOrder> opened;
  late int retries;
  late int browses;

  setUp(() {
    opened = [];
    retries = 0;
    browses = 0;
  });

  Future<void> show(
    WidgetTester tester,
    MyOrdersState state, {
    double width = 1080,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyOrdersList(
            state: state,
            onOpen: opened.add,
            onRetry: () => retries++,
            onBrowse: () => browses++,
          ),
        ),
      ),
    );
  }

  testWidgets('while loading, a spinner shows', (tester) async {
    await show(tester, const MyOrdersState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('on failure, the message and Retry show', (tester) async {
    await show(
      tester,
      const MyOrdersState(
        status: MyOrdersStatus.failure,
        errorMessage: 'No internet connection.',
      ),
    );

    expect(find.text('No internet connection.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('no orders: a big icon and Browse restaurants', (tester) async {
    await show(tester, loaded([]));

    expect(find.text('No orders yet'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
    await tester.tap(find.text('Browse restaurants'));
    expect(browses, 1);
  });

  testWidgets('Active orders come first, then Past', (tester) async {
    await show(
      tester,
      loaded([
        orderWith('aaaaaa1', OrderStatus.preparing),
        orderWith('bbbbbb1', OrderStatus.completed),
        orderWith('cccccc1', OrderStatus.placed),
        orderWith('dddddd1', OrderStatus.rejected),
      ]),
    );

    double y(Finder finder) => tester.getTopLeft(finder).dy;
    final activeTitle = y(find.text('Active'));
    final pastTitle = y(find.text('Past'));
    final a = y(find.byKey(const ValueKey('order_aaaaaa1')));
    final c = y(find.byKey(const ValueKey('order_cccccc1')));
    final b = y(find.byKey(const ValueKey('order_bbbbbb1')));
    final d = y(find.byKey(const ValueKey('order_dddddd1')));

    expect(activeTitle, lessThan(a));
    expect(a, lessThan(c));
    expect(c, lessThan(pastTitle));
    expect(pastTitle, lessThan(b));
    expect(b, lessThan(d));
  });

  testWidgets('only past orders: no Active title', (tester) async {
    await show(tester, loaded([orderWith('bbbbbb1', OrderStatus.completed)]));

    expect(find.text('Active'), findsNothing);
    expect(find.text('Past'), findsOneWidget);
  });

  testWidgets('only active orders: no Past title', (tester) async {
    await show(tester, loaded([orderWith('aaaaaa1', OrderStatus.accepted)]));

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Past'), findsNothing);
  });

  testWidgets('a row shows the name, number, time, items and price', (
    tester,
  ) async {
    await show(tester, loaded([orderWith('ab12cd34', OrderStatus.placed)]));

    expect(find.text('Kottu Corner'), findsOneWidget);
    expect(find.text('#AB12CD · 25 Nov, 2:28 PM'), findsOneWidget);
    expect(find.text('3 items · Rs. 2,650'), findsOneWidget);
    expect(find.text('Placed'), findsOneWidget);
    expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
  });

  testWidgets('one dish says "1 item"', (tester) async {
    await show(
      tester,
      loaded([
        orderWith('aaaaaa1', OrderStatus.placed, items: const [tea]),
      ]),
    );

    expect(find.text('1 item · Rs. 2,650'), findsOneWidget);
  });

  testWidgets('the pill is orange going, green ready or done, red stopped',
      (tester) async {
    await show(
      tester,
      loaded([
        orderWith('aaaaaa1', OrderStatus.preparing),
        orderWith('bbbbbb1', OrderStatus.ready),
        orderWith('cccccc1', OrderStatus.completed),
        orderWith('dddddd1', OrderStatus.cancelled),
      ]),
    );

    expect(
      pillColors(tester, 'aaaaaa1'),
      (AppTheme.deepOrange, AppTheme.softOrange),
    );
    expect(
      pillColors(tester, 'bbbbbb1'),
      (AppTheme.successGreen, AppTheme.successBg),
    );
    expect(
      pillColors(tester, 'cccccc1'),
      (AppTheme.successGreen, AppTheme.successBg),
    );
    expect(
      pillColors(tester, 'dddddd1'),
      (AppTheme.dangerRed, AppTheme.dangerBg),
    );
  });

  testWidgets('tapping a row opens that order', (tester) async {
    final first = orderWith('aaaaaa1', OrderStatus.placed);
    final second = orderWith('bbbbbb1', OrderStatus.completed);
    await show(tester, loaded([first, second]));

    await tester.tap(find.byKey(const ValueKey('order_bbbbbb1')));

    expect(opened, [second]);
  });

  testWidgets('a small phone with a long name and status has no overflow', (
    tester,
  ) async {
    await show(
      tester,
      loaded([
        orderWith(
          'aaaaaa1',
          OrderStatus.ready,
          restaurantName: 'The Very Long Name Kottu And Rice Corner Colombo',
        ),
      ]),
      width: 960,
    );

    expect(tester.takeException(), isNull);
  });
}