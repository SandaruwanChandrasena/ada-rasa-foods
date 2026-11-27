import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/features/auth/domain/app_user.dart';
import 'package:ada_rasa_foods/features/auth/domain/user_role.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/owner/my_restaurant_cubit.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/owner/owner_profile_page.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/owner/restaurant_photo_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

class MockMyRestaurantCubit extends MockCubit<MyRestaurantState>
    implements MyRestaurantCubit {}

class MockRestaurantPhotoCubit extends MockCubit<RestaurantPhotoState>
    implements RestaurantPhotoCubit {}

const owner = AppUser(
  uid: 'o1',
  name: 'sandaruwan',
  email: 'owner@test.com',
  phone: '0712345678',
  role: UserRole.restaurant,
  restaurantId: 'r1',
);

const ownerNoPhone = AppUser(
  uid: 'o1',
  name: 'Sandaruwan',
  email: 'owner@test.com',
  role: UserRole.restaurant,
  restaurantId: 'r1',
);

const openShop = Restaurant(
  id: 'r1',
  name: 'Kottu Corner',
  cuisine: 'Sri Lankan',
  ownerId: 'o1',
  address: 'Colombo',
  latitude: 6.9,
  longitude: 79.8,
);

const closedShop = Restaurant(
  id: 'r1',
  name: 'Kottu Corner',
  cuisine: 'Sri Lankan',
  ownerId: 'o1',
  address: 'Colombo',
  latitude: 6.9,
  longitude: 79.8,
  isOpen: false,
);

MyRestaurantState loaded(Restaurant restaurant, {bool saving = false}) {
  return MyRestaurantState(
    view: MyRestaurantView.loaded,
    restaurant: restaurant,
    isSaving: saving,
  );
}

void main() {
  late MockAuthCubit authCubit;
  late MockMyRestaurantCubit myRestaurant;
  late MockRestaurantPhotoCubit photo;

  setUp(() {
    authCubit = MockAuthCubit();
    myRestaurant = MockMyRestaurantCubit();
    photo = MockRestaurantPhotoCubit();
    when(() => authCubit.state)
        .thenReturn(const AuthState.authenticated(owner));
    when(() => authCubit.signOut()).thenAnswer((_) async {});
    when(() => myRestaurant.state).thenReturn(loaded(openShop));
    when(() => myRestaurant.setOpen(any())).thenAnswer((_) async {});
    when(() => photo.state).thenReturn(const RestaurantPhotoState());
  });

  Future<void> show(WidgetTester tester, {bool settle = true}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<MyRestaurantCubit>.value(value: myRestaurant),
          BlocProvider<RestaurantPhotoCubit>.value(value: photo),
        ],
        child: const MaterialApp(home: OwnerProfilePage()),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Finder signOutButton() => find
      .ancestor(
        of: find.text('Sign out'),
        matching: find.byWidgetPredicate((widget) => widget is TextButton),
      )
      .first;

  Future<void> tapSignOut(WidgetTester tester) async {
    await tester.ensureVisible(signOutButton());
    await tester.pumpAndSettle();
    await tester.tap(signOutButton());
    await tester.pumpAndSettle();
  }

  group('owner details', () {
    testWidgets('shows the letter, name, role, email and phone',
        (tester) async {
      await show(tester);

      expect(find.text('Sandaruwan'), findsNothing);
      expect(find.text('sandaruwan'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      expect(find.text('Restaurant owner'), findsOneWidget);
      expect(find.text('owner@test.com'), findsOneWidget);
      expect(find.text('071 234 5678'), findsOneWidget);
    });

    testWidgets('no phone line when the owner has no phone',
        (tester) async {
      when(() => authCubit.state)
          .thenReturn(const AuthState.authenticated(ownerNoPhone));

      await show(tester);

      expect(find.byIcon(Icons.phone_rounded), findsNothing);
      expect(find.byIcon(Icons.email_rounded), findsOneWidget);
    });

    testWidgets('shows the restaurant photo card', (tester) async {
      await show(tester);

      expect(find.text('Restaurant photo'), findsOneWidget);
    });
  });

  group('Open card', () {
    testWidgets('an open restaurant shows Open for orders and the switch on',
        (tester) async {
      await show(tester);

      expect(find.text('Open for orders'), findsOneWidget);
      expect(find.text('Customers can order.'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('a closed restaurant shows Closed in red', (tester) async {
      when(() => myRestaurant.state).thenReturn(loaded(closedShop));

      await show(tester);

      final title = tester.widget<Text>(find.text('Closed'));
      expect(title.style?.color, AppTheme.dangerRed);
      expect(find.text('Customers cannot order.'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('hidden until the restaurant loads', (tester) async {
      when(() => myRestaurant.state).thenReturn(const MyRestaurantState());

      await show(tester);

      expect(find.text('Open for orders'), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('opening does not ask first', (tester) async {
      when(() => myRestaurant.state).thenReturn(loaded(closedShop));
      await show(tester);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Close now?'), findsNothing);
      verify(() => myRestaurant.setOpen(true)).called(1);
    });

    testWidgets('closing asks first, and Cancel keeps it open',
        (tester) async {
      await show(tester);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Close now?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Close now?'), findsNothing);
      verifyNever(() => myRestaurant.setOpen(any()));
    });

    testWidgets('Close in the question closes the restaurant',
        (tester) async {
      await show(tester);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pumpAndSettle();

      verify(() => myRestaurant.setOpen(false)).called(1);
    });

    testWidgets('a spinner shows while it saves', (tester) async {
      when(() => myRestaurant.state)
          .thenReturn(loaded(openShop, saving: true));

      await show(tester, settle: false);

      expect(find.byType(Switch), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('Sign out', () {
    testWidgets('is a soft red button', (tester) async {
      await show(tester);

      final button = tester.widget<TextButton>(signOutButton());
      final style = button.style!;
      expect(style.backgroundColor?.resolve({}), AppTheme.dangerBg);
      expect(style.foregroundColor?.resolve({}), AppTheme.dangerRed);
    });

    testWidgets('asks first, and Cancel keeps you signed in',
        (tester) async {
      await show(tester);

      await tapSignOut(tester);

      expect(find.text('Sign out?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsNothing);
      verifyNever(() => authCubit.signOut());
    });

    testWidgets('Sign out in the question signs you out', (tester) async {
      await show(tester);

      await tapSignOut(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      verify(() => authCubit.signOut()).called(1);
    });
  });
}