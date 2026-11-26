import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/round_icon_button.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_header.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
import 'package:ada_rasa_foods/features/auth/presentation/google_sign_in_button.dart';
import 'package:ada_rasa_foods/features/auth/presentation/sign_up_screen.dart';
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

  Future<void> show(
    WidgetTester tester, {
    double width = 1080,
    bool settle = true,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/sign-up',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(
            body: Text('Sign in page'),
          ),
        ),
        GoRoute(
          path: '/sign-up',
          builder: (context, state) => const SignUpScreen(),
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
    // A loading spinner never settles, so then wait a fixed time.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(seconds: 2));
    }
  }

  // The page is long. This scrolls until the widget can be tapped.
  // Each text box has its own small scroller, so name the page's one.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the title, the 4 boxes and the Google button',
      (tester) async {
    await show(tester);

    expect(find.text('Create Account'), findsNWidgets(2));
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);

    await scrollTo(tester, find.byType(GoogleSignInButton));
    expect(find.text('Or continue with'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('the header is short, so the title sits under the photo',
      (tester) async {
    await show(tester);

    final header = tester.widget<AuthHeader>(find.byType(AuthHeader));
    expect(header.height, 180);
  });

  testWidgets('the box icons are rounded and orange', (tester) async {
    await show(tester);

    Color? colorOf(IconData icon) =>
        tester.widget<Icon>(find.byIcon(icon).first).color;

    expect(colorOf(Icons.person_rounded), AppTheme.brandOrange);
    expect(colorOf(Icons.email_rounded), AppTheme.brandOrange);
    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));
    expect(colorOf(Icons.lock_rounded), AppTheme.brandOrange);
  });

  testWidgets('the round back button goes to sign in', (tester) async {
    await show(tester);

    final back = tester.widget<RoundIconButton>(find.byType(RoundIconButton));
    expect(back.icon, Icons.arrow_back_rounded);

    await tester.tap(find.byType(RoundIconButton));
    await tester.pumpAndSettle();

    expect(find.text('Sign in page'), findsOneWidget);
  });

  testWidgets('the Google button signs in with Google', (tester) async {
    await show(tester);
    await scrollTo(tester, find.byType(GoogleSignInButton));

    await tester.tap(find.byType(GoogleSignInButton));
    await tester.pump();

    verify(() => auth.signInWithGoogle()).called(1);
  });

  testWidgets('while loading, the Google button cannot be tapped',
      (tester) async {
    when(() => auth.state).thenReturn(
      const AuthState.unauthenticated(isLoading: true),
    );
    await show(tester, settle: false);

    final google = tester.widget<GoogleSignInButton>(
      find.byType(GoogleSignInButton),
    );
    expect(google.onPressed, isNull);
  });

  testWidgets('a small phone has no overflow', (tester) async {
    await show(tester, width: 960);

    expect(tester.takeException(), isNull);
  });
}