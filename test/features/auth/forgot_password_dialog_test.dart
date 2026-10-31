import 'package:ada_rasa_foods/core/di/injection.dart';
import 'package:ada_rasa_foods/features/auth/domain/auth_repository.dart';
import 'package:ada_rasa_foods/features/auth/presentation/forgot_password_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/forgot_password_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    when(() => repository.sendPasswordReset(any())).thenAnswer((_) async {});
    // The pop-up gets its cubit from sl, like in the app.
    sl.registerFactory<ForgotPasswordCubit>(
      () => ForgotPasswordCubit(repository),
    );
  });

  tearDown(() => sl.unregister<ForgotPasswordCubit>());

  // A page with a button that opens the pop-up, on a phone-sized screen.
  Future<void> showPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => ForgotPasswordDialog.show(
                  context,
                  email: 'nimal@test.com',
                ),
                child: const Text('Forgot'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // The size of the whole pop-up (the outer grow animation).
  double popUpScale(WidgetTester tester, String title) {
    final scale = tester.widget<ScaleTransition>(
      find
          .ancestor(
            of: find.text(title),
            matching: find.byType(ScaleTransition),
          )
          .last,
    );
    return scale.scale.value;
  }

  testWidgets('opens by growing and fading in', (tester) async {
    await showPage(tester);

    await tester.tap(find.text('Forgot'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Halfway: bigger than 92%, but not full size yet.
    final half = popUpScale(tester, 'Reset password');
    expect(half, greaterThan(0.92));
    expect(half, lessThan(1));

    await tester.pumpAndSettle();
    expect(popUpScale(tester, 'Reset password'), 1);
  });

  testWidgets('Cancel closes it with a fade, not at once', (tester) async {
    await showPage(tester);
    await tester.tap(find.text('Forgot'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Still fading out.
    expect(find.text('Reset password'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsNothing);
  });

  testWidgets('a bad email shows a message and sends nothing',
      (tester) async {
    await showPage(tester);
    await tester.tap(find.text('Forgot'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'nimal');
    await tester.tap(find.text('Send link'));
    await tester.pumpAndSettle();

    expect(find.text('This email address is not valid.'), findsOneWidget);
    verifyNever(() => repository.sendPasswordReset(any()));
  });

  testWidgets('Send link cross-fades into "Check your email"',
      (tester) async {
    await showPage(tester);
    await tester.tap(find.text('Forgot'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send link'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // Halfway: the old form is fading out while the message fades in.
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Check your email'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsNothing);
    expect(find.text('Check your email'), findsOneWidget);
    verify(() => repository.sendPasswordReset('nimal@test.com')).called(1);
  });

  testWidgets('glides up slowly when the keyboard opens', (tester) async {
    await showPage(tester);
    await tester.tap(find.text('Forgot'));
    await tester.pumpAndSettle();

    // The keyboard opens: 300 px high.
    tester.view.viewInsets = FakeViewPadding(
      bottom: 300 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    final glide = tester.widget<AnimatedPadding>(
      find
          .ancestor(
            of: find.text('Reset password'),
            matching: find.byType(AnimatedPadding),
          )
          .last,
    );
    expect(glide.padding, const EdgeInsets.only(bottom: 300));
    expect(glide.duration, const Duration(milliseconds: 300));

    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsOneWidget);
  });
}