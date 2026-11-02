import 'package:ada_rasa_foods/features/auth/domain/app_user.dart';
import 'package:ada_rasa_foods/features/auth/domain/user_role.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
import 'package:ada_rasa_foods/features/orders/domain/food_order.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_item.dart';
import 'package:ada_rasa_foods/features/orders/domain/order_status.dart';
import 'package:ada_rasa_foods/features/orders/presentation/restaurant_orders_cubit.dart';
import 'package:ada_rasa_foods/features/orders/presentation/restaurant_orders_screen.dart';
import 'package:ada_rasa_foods/features/orders/presentation/restaurant_orders_state.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/my_restaurant_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

class MockBoardCubit extends MockCubit<RestaurantOrdersState>
    implements RestaurantOrdersCubit {}

class MockMyRestaurantCubit extends MockCubit<MyRestaurantState>
    implements MyRestaurantCubit {}

Restaurant kottu({bool isOpen = true}) {
  return Restaurant(
    id: 'r1',
    name: 'Kottu Corner',
    cuisine: 'Sri Lankan',
    ownerId: 'o1',
    address: 'Colombo',
    latitude: 6.9,
    longitude: 79.8,
    isOpen: isOpen,
  );
}

MyRestaurantState restaurantLoaded({bool isOpen = true}) {
  return MyRestaurantState(
    view: MyRestaurantView.loaded,
    restaurant: kottu(isOpen: isOpen),
  );
}

const owner = AppUser(
  uid: 'o1',
  name: 'Owner',
  email: 'owner@test.com',
  role: UserRole.restaurant,
);

FoodOrder order(
  String id, {
  OrderStatus status = OrderStatus.placed,
  bool card = false,
  PaymentStatus? payment,
  String phone = '0712345678',
}) {
  return FoodOrder(
    id: id,
    customerId: 'u1',
    customerName: 'Nimal',
    customerPhone: phone,
    restaurantId: 'r1',
    restaurantName: 'Kottu Corner',
    restaurantAddress: 'Colombo',
    items: const [
      OrderItem(dishId: 'd1', name: 'Chicken Kottu', price: 1200, quantity: 2),
    ],
    total: 2400,
    paymentMethod: card ? PaymentMethod.card : PaymentMethod.cash,
    paymentStatus:
        payment ?? (card ? PaymentStatus.paid : PaymentStatus.pending),
    cardBrand: card ? 'visa' : '',
    cardLast4: card ? '4242' : '',
    status: status,
  );
}

void main() {
  late MockAuthCubit authCubit;
  late MockBoardCubit board;
  late MockMyRestaurantCubit myRestaurant;
  late List<String> calledPhones;
  late bool callWorks;

  setUpAll(() {
    registerFallbackValue(order('fallback'));
    registerFallbackValue(OrderStatus.placed);
  });

  setUp(() {
    authCubit = MockAuthCubit();
    board = MockBoardCubit();
    myRestaurant = MockMyRestaurantCubit();
    calledPhones = [];
    callWorks = true;
    when(() => myRestaurant.state).thenReturn(restaurantLoaded());
    when(() => myRestaurant.setOpen(any())).thenAnswer((_) async {});
    when(() => authCubit.state)
        .thenReturn(const AuthState.authenticated(owner));
    when(() => authCubit.signOut()).thenAnswer((_) async {});
    when(() => board.move(any(), any())).thenAnswer((_) async {});
  });

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<bool> fakeCall(String phone) async {
    calledPhones.add(phone);
    return callWorks;
  }

  Widget boardApp() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<RestaurantOrdersCubit>.value(value: board),
        BlocProvider<MyRestaurantCubit>.value(value: myRestaurant),
      ],
      child: MaterialApp(home: RestaurantOrdersView(callPhone: fakeCall)),
    );
  }

  Future<void> showBoard(
    WidgetTester tester,
    RestaurantOrdersState state, {
    Stream<RestaurantOrdersState>? changes,
  }) async {
    phoneSize(tester);
    if (changes != null) {
      whenListen(board, changes, initialState: state);
    } else {
      when(() => board.state).thenReturn(state);
    }

    await tester.pumpWidget(
      boardApp(),
    );
    await tester.pumpAndSettle();
  }

  RestaurantOrdersState loaded({
    List<FoodOrder> open = const [],
    List<FoodOrder> done = const [],
    Set<String> busyIds = const {},
  }) {
    return RestaurantOrdersState(
      view: BoardView.loaded,
      open: open,
      done: done,
      doneLoaded: true,
      busyIds: busyIds,
    );
  }

  Future<void> openTab(WidgetTester tester, String text) async {
    await tester.tap(find.textContaining(text).first);
    await tester.pumpAndSettle();
  }

  testWidgets('says so when no restaurant is linked', (tester) async {
    phoneSize(tester);

    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: authCubit,
        child: const MaterialApp(home: RestaurantOrdersScreen()),
      ),
    );

    expect(
      find.text('No restaurant is linked to your account. Ask the admin.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a spinner while loading', (tester) async {
    phoneSize(tester);
    when(() => board.state).thenReturn(const RestaurantOrdersState());

    await tester.pumpWidget(
      boardApp(),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a load error shows Retry', (tester) async {
    await showBoard(
      tester,
      const RestaurantOrdersState(
        view: BoardView.failure,
        errorMessage: 'No internet connection.',
      ),
    );

    await tester.tap(find.text('Retry'));

    expect(find.text('No internet connection.'), findsOneWidget);
    verify(() => board.retry()).called(1);
  });

  testWidgets('tabs show the counts', (tester) async {
    await showBoard(
      tester,
      loaded(
        open: [
          order('aaaaaa1'),
          order('bbbbbb2'),
          order('cccccc3', status: OrderStatus.preparing),
        ],
      ),
    );

    expect(find.text('New (2)'), findsOneWidget);
    expect(find.text('Active (1)'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('a new order shows its details', (tester) async {
    await showBoard(tester, loaded(open: [order('abcdef1')]));

    expect(find.text('Order #ABCDEF'), findsOneWidget);
    expect(find.text('Nimal'), findsOneWidget);
    expect(find.text('0712345678'), findsOneWidget);
    expect(find.text('2 x Chicken Kottu'), findsOneWidget);
    expect(find.text('Rs. 2,400'), findsOneWidget);
    expect(find.text('Cash, pay at pickup'), findsOneWidget);
  });

  testWidgets('an old order with no phone says No phone', (tester) async {
    await showBoard(tester, loaded(open: [order('abcdef1', phone: '')]));

    expect(find.text('No phone'), findsOneWidget);
  });

  testWidgets('Accept moves the order to accepted', (tester) async {
    final placed = order('abcdef1');
    await showBoard(tester, loaded(open: [placed]));

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    verify(() => board.move(placed, OrderStatus.accepted)).called(1);
  });

  testWidgets('Reject on a card order asks first and says refund',
      (tester) async {
    final placed = order('abcdef1', card: true);
    await showBoard(tester, loaded(open: [placed]));

    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();

    expect(find.text('Reject order #ABCDEF?'), findsOneWidget);
    expect(find.textContaining('refunded to the card'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();

    verify(() => board.move(placed, OrderStatus.rejected)).called(1);
  });

  testWidgets('Keep closes the reject dialog and changes nothing',
      (tester) async {
    await showBoard(tester, loaded(open: [order('abcdef1')]));

    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();

    expect(find.text('Reject order #ABCDEF?'), findsNothing);
    verifyNever(() => board.move(any(), any()));
  });

  testWidgets('an accepted order shows Start preparing', (tester) async {
    final accepted = order('abcdef1', status: OrderStatus.accepted);
    await showBoard(tester, loaded(open: [accepted]));
    await openTab(tester, 'Active');

    await tester.tap(find.text('Start preparing'));
    await tester.pumpAndSettle();

    verify(() => board.move(accepted, OrderStatus.preparing)).called(1);
  });

  testWidgets('a preparing order shows Mark ready', (tester) async {
    final preparing = order('abcdef1', status: OrderStatus.preparing);
    await showBoard(tester, loaded(open: [preparing]));
    await openTab(tester, 'Active');

    await tester.tap(find.text('Mark ready'));
    await tester.pumpAndSettle();

    verify(() => board.move(preparing, OrderStatus.ready)).called(1);
  });

  testWidgets('a ready cash order asks if the money was collected',
      (tester) async {
    final ready = order('abcdef1', status: OrderStatus.ready);
    await showBoard(tester, loaded(open: [ready]));
    await openTab(tester, 'Active');

    expect(find.text('Collect Rs. 2,400'), findsOneWidget);
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(find.text('Did you collect Rs. 2,400?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Completed').last);
    await tester.pumpAndSettle();

    verify(() => board.move(ready, OrderStatus.completed)).called(1);
  });

  testWidgets('a ready card order completes at once', (tester) async {
    final ready = order('abcdef1', status: OrderStatus.ready, card: true);
    await showBoard(tester, loaded(open: [ready]));
    await openTab(tester, 'Active');

    expect(find.textContaining('Collect'), findsNothing);
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verify(() => board.move(ready, OrderStatus.completed)).called(1);
  });

  testWidgets('a saving order shows a spinner, not buttons', (tester) async {
    phoneSize(tester);
    when(() => board.state).thenReturn(
      loaded(open: [order('abcdef1')], busyIds: {'abcdef1'}),
    );

    await tester.pumpWidget(
      boardApp(),
    );
    // The spinner never stops, so we pump a little, not until settled.
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Accept'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('empty tabs say so', (tester) async {
    await showBoard(tester, loaded());

    expect(find.text('No new orders.'), findsOneWidget);
    await openTab(tester, 'Active');
    expect(find.text('No active orders.'), findsOneWidget);
    await openTab(tester, 'Done');
    expect(find.text('No finished orders yet.'), findsOneWidget);
  });

  testWidgets('Done shows a refunded card order with no buttons',
      (tester) async {
    final rejected = order(
      'abcdef1',
      status: OrderStatus.rejected,
      card: true,
      payment: PaymentStatus.refunded,
    );
    await showBoard(tester, loaded(done: [rejected]));
    await openTab(tester, 'Done');

    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Refunded (demo)'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('a step message shows in a bar', (tester) async {
    final first = loaded(open: [order('abcdef1')]);
    final second = RestaurantOrdersState(
      view: BoardView.loaded,
      open: first.open,
      doneLoaded: true,
      notice: 'The customer cancelled this order.',
      noticeId: 1,
    );

    await showBoard(
      tester,
      first,
      changes: Stream.value(second),
    );

    expect(find.text('The customer cancelled this order.'), findsOneWidget);
  });

  testWidgets('a new order alert shows its number', (tester) async {
    final first = loaded();
    final second = RestaurantOrdersState(
      view: BoardView.loaded,
      open: [order('xyz7891')],
      doneLoaded: true,
      newOrderNumber: 'XYZ789',
      newOrderAlertId: 1,
    );

    await showBoard(
      tester,
      first,
      changes: Stream.value(second),
    );

    expect(find.text('New order #XYZ789'), findsOneWidget);
  });

  testWidgets('Sign out signs out', (tester) async {
    await showBoard(tester, loaded());

    await tester.tap(find.byTooltip('Sign out'));

    verify(() => authCubit.signOut()).called(1);
  });

  testWidgets('the top bar shows the restaurant name', (tester) async {
    await showBoard(tester, loaded());

    expect(find.text('Kottu Corner'), findsOneWidget);
    expect(find.text('Orders'), findsNothing);
  });

  testWidgets('the title says Orders until the restaurant loads',
      (tester) async {
    when(() => myRestaurant.state).thenReturn(const MyRestaurantState());

    await showBoard(tester, loaded());

    expect(find.text('Orders'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('an open restaurant shows Open and no red strip',
      (tester) async {
    await showBoard(tester, loaded());

    expect(find.text('Open'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('Closed. Customers cannot order now.'), findsNothing);
  });

  testWidgets('a closed restaurant shows Closed and a red strip',
      (tester) async {
    when(() => myRestaurant.state)
        .thenReturn(restaurantLoaded(isOpen: false));

    await showBoard(tester, loaded());

    expect(find.text('Closed'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('Closed. Customers cannot order now.'), findsOneWidget);
  });

  testWidgets('tapping the switch closes the restaurant', (tester) async {
    await showBoard(tester, loaded());

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    verify(() => myRestaurant.setOpen(false)).called(1);
  });

  testWidgets('the switch is locked while saving', (tester) async {
    when(() => myRestaurant.state).thenReturn(
      MyRestaurantState(
        view: MyRestaurantView.loaded,
        restaurant: kottu(),
        isSaving: true,
      ),
    );

    await showBoard(tester, loaded());

    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });

  testWidgets('a switch message shows in a bar', (tester) async {
    final second = MyRestaurantState(
      view: MyRestaurantView.loaded,
      restaurant: kottu(isOpen: false),
      notice: 'Your restaurant is closed. Customers cannot order.',
      noticeId: 1,
    );
    whenListen(
      myRestaurant,
      Stream.value(second),
      initialState: restaurantLoaded(),
    );

    await showBoard(tester, loaded());

    expect(
      find.text('Your restaurant is closed. Customers cannot order.'),
      findsOneWidget,
    );
  });

  testWidgets('Call opens the phone app with the number', (tester) async {
    await showBoard(tester, loaded(open: [order('abcdef1')]));

    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();

    expect(calledPhones, ['0712345678']);
  });

  testWidgets('no Call button when there is no phone', (tester) async {
    await showBoard(tester, loaded(open: [order('abcdef1', phone: '')]));

    expect(find.text('Call'), findsNothing);
  });

  testWidgets('says so when the phone app cannot open', (tester) async {
    callWorks = false;
    await showBoard(tester, loaded(open: [order('abcdef1')]));

    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open the phone app.'), findsOneWidget);
  });
}