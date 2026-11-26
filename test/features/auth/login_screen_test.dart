import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
import 'package:ada_rasa_foods/features/auth/presentation/google_sign_in_button.dart';
import 'package:ada_rasa_foods/features/auth/presentation/login_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late MockAuthCubit auth;

  setUp(() {
    auth = MockAuthCubit();
    when(() => auth.state).thenReturn(const AuthState.unauthenticated());
    when(() => auth.signInWithGoogle()).thenAnswer((_) async {});
  });

  Future<void> show(WidgetTester tester, {double width = 1080}) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/sign-up',
          builder: (context, state) => const Scaffold(
            body: Text('Sign up page'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Each text box has its own small scroller, so name the page's one.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the email and password icons are rounded and orange',
      (tester) async {
    await show(tester);

    final email = tester.widget<Icon>(find.byIcon(Icons.email_rounded));
    final lock = tester.widget<Icon>(find.byIcon(Icons.lock_rounded));

    expect(email.color, AppTheme.brandOrange);
    expect(lock.color, AppTheme.brandOrange);
    expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
  });

  testWidgets('the Google button is still there and works', (tester) async {
    await show(tester);
    await scrollTo(tester, find.byType(GoogleSignInButton));

    await tester.tap(find.byType(GoogleSignInButton));
    await tester.pump();

    verify(() => auth.signInWithGoogle()).called(1);
  });

  testWidgets('Sign Up opens the sign up page', (tester) async {
    await show(tester);
    await scrollTo(tester, find.text('Sign Up'));

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Sign up page'), findsOneWidget);
  });

  testWidgets('a small phone has no overflow', (tester) async {
    await show(tester, width: 960);

    expect(tester.takeException(), isNull);
  });
}