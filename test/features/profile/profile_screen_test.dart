import 'package:ada_rasa_foods/core/router/app_router.dart';
import 'package:ada_rasa_foods/features/auth/domain/app_user.dart';
import 'package:ada_rasa_foods/features/auth/domain/auth_failure.dart';
import 'package:ada_rasa_foods/features/auth/domain/auth_repository.dart';
import 'package:ada_rasa_foods/features/auth/domain/user_role.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
import 'package:ada_rasa_foods/features/auth/presentation/forgot_password_cubit.dart';
import 'package:ada_rasa_foods/features/profile/presentation/profile_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

const nimal = AppUser(
  uid: 'u1',
  name: 'nimal Perera',
  email: 'nimal@test.com',
  phone: '0712345678',
  role: UserRole.customer,
);

const noPhone = AppUser(
  uid: 'u1',
  name: 'Nimal',
  email: 'nimal@test.com',
  role: UserRole.customer,
);

void main() {
  late MockAuthRepository repository;
  late MockAuthCubit authCubit;

  setUp(() {
    repository = MockAuthRepository();
    authCubit = MockAuthCubit();
    when(() => authCubit.signOut()).thenAnswer((_) async {});
    when(() => repository.sendPasswordReset(any()))
        .thenAnswer((_) async {});
  });

  Future<void> show(
    WidgetTester tester, {
    AppUser user = nimal,
    bool canChangePassword = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    when(() => authCubit.state).thenReturn(AuthState.authenticated(user));

    // Simple pages stand in for the real ones.
    final router = GoRouter(
      initialLocation: AppRoutes.profile,
      routes: [
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) =>
              ProfileView(canChangePassword: canChangePassword),
        ),
        GoRoute(
          path: AppRoutes.editProfile,
          builder: (context, state) => const Text('Edit page'),
        ),
        GoRoute(
          path: AppRoutes.myOrders,
          builder: (context, state) => const Text('Orders page'),
        ),
        GoRoute(
          path: AppRoutes.myCards,
          builder: (context, state) => const Text('Cards page'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<ForgotPasswordCubit>(
            create: (_) => ForgotPasswordCubit(repository),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the letter, name, email, phone, and role',
      (tester) async {
    await show(tester);

    expect(find.text('N'), findsOneWidget);
    expect(find.text('nimal Perera'), findsOneWidget);
    expect(find.text('nimal@test.com'), findsOneWidget);
    expect(find.text('071 234 5678'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Phone not added'), findsNothing);
  });

  testWidgets('a missing phone shows "Phone not added"', (tester) async {
    await show(tester, user: noPhone);

    expect(find.text('Phone not added'), findsOneWidget);
  });

  testWidgets('Change password is hidden for Google users',
      (tester) async {
    await show(tester, canChangePassword: false);

    expect(find.text('Change password'), findsNothing);
    expect(find.text('Edit name and phone'), findsOneWidget);
  });

  testWidgets('Edit name and phone opens the edit page', (tester) async {
    await show(tester);

    await tester.tap(find.text('Edit name and phone'));
    await tester.pumpAndSettle();

    expect(find.text('Edit page'), findsOneWidget);
  });

  testWidgets('My orders opens the orders page', (tester) async {
    await show(tester);

    await tester.tap(find.text('My orders'));
    await tester.pumpAndSettle();

    expect(find.text('Orders page'), findsOneWidget);
  });

  testWidgets('My cards opens the cards page', (tester) async {
    await show(tester);

    await tester.tap(find.text('My cards'));
    await tester.pumpAndSettle();

    expect(find.text('Cards page'), findsOneWidget);
  });

  testWidgets('Sign out asks first, and Cancel keeps you signed in',
      (tester) async {
    await show(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsNothing);
    verifyNever(() => authCubit.signOut());
  });

  testWidgets('Sign out in the question signs you out', (tester) async {
    await show(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    verify(() => authCubit.signOut()).called(1);
  });

  testWidgets('Change password sends a reset link to my email',
      (tester) async {
    await show(tester);

    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    expect(find.textContaining('nimal@test.com'), findsNWidgets(2));

    await tester.tap(find.text('Send link'));
    await tester.pumpAndSettle();

    verify(() => repository.sendPasswordReset('nimal@test.com')).called(1);
    expect(
      find.text(
        'We sent a reset link to your email. Please check your inbox.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Cancel on Change password sends nothing', (tester) async {
    await show(tester);

    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => repository.sendPasswordReset(any()));
  });

  testWidgets('a reset error shows its message', (tester) async {
    when(() => repository.sendPasswordReset(any())).thenThrow(
      const AuthFailure('No internet connection. Please try again.'),
    );
    await show(tester);

    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send link'));
    await tester.pumpAndSettle();

    expect(
      find.text('No internet connection. Please try again.'),
      findsOneWidget,
    );
  });
}