import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/features/orders/presentation/checkout/checkout_state.dart';
import 'package:ada_rasa_foods/features/orders/presentation/checkout/payment_steps.dart';
import 'package:ada_rasa_foods/features/payments/presentation/pay/payment_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

PaymentState paymentWith(DemoPaymentStatus status) =>
    PaymentState(status: status, amount: 2400);

CheckoutState checkoutWith(CheckoutStatus status) =>
    CheckoutState(status: status);

// The row of one step, found by its number.
Finder stepRow(int index) => find.byKey(ValueKey('payment_step_$index'));

bool rowHas(int index, Finder inner) =>
    find.descendant(of: stepRow(index), matching: inner).evaluate().isNotEmpty;

bool isDone(int index) =>
    rowHas(index, find.byIcon(Icons.check_circle_rounded));

bool isRunning(int index) =>
    rowHas(index, find.byType(CircularProgressIndicator));

bool isWaiting(int index) =>
    rowHas(index, find.byIcon(Icons.radio_button_unchecked_rounded));

void main() {
  group('paymentStepOf', () {
    test('"Checking card" runs first', () {
      expect(
        paymentStepOf(
          paymentWith(DemoPaymentStatus.processing),
          checkoutWith(CheckoutStatus.ready),
          cardChecked: false,
        ),
        0,
      );
    });

    test('"Paying" runs once the card is checked', () {
      expect(
        paymentStepOf(
          paymentWith(DemoPaymentStatus.processing),
          checkoutWith(CheckoutStatus.ready),
          cardChecked: true,
        ),
        1,
      );
    });

    test('"Saving order" runs after the payment, until it is saved', () {
      final payment = paymentWith(DemoPaymentStatus.approved);

      for (final status in [CheckoutStatus.ready, CheckoutStatus.placing]) {
        expect(
          paymentStepOf(payment, checkoutWith(status), cardChecked: true),
          2,
        );
      }
    });

    test('all steps are done when the order is saved', () {
      expect(
        paymentStepOf(
          paymentWith(DemoPaymentStatus.approved),
          checkoutWith(CheckoutStatus.placed),
          cardChecked: true,
        ),
        3,
      );
    });

    test('a saved-order failure stays on "Saving order"', () {
      expect(
        paymentStepOf(
          paymentWith(DemoPaymentStatus.approved),
          checkoutWith(CheckoutStatus.failure),
          cardChecked: true,
        ),
        2,
      );
    });

    test('idle and declined go back to the first step', () {
      for (final status in [
        DemoPaymentStatus.idle,
        DemoPaymentStatus.declined,
      ]) {
        expect(
          paymentStepOf(
            paymentWith(status),
            checkoutWith(CheckoutStatus.ready),
            cardChecked: true,
          ),
          0,
        );
      }
    });
  });

  group('PaymentSteps', () {
    Future<void> show(
      WidgetTester tester,
      int current, {
      bool reduceMotion = false,
      double width = 1080,
    }) async {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: reduceMotion,
              ),
              child: Scaffold(
                body: Center(child: PaymentSteps(current: current)),
              ),
            ),
          ),
        ),
      );
      // A spinner never settles, so pump one frame only.
      await tester.pump();
    }

    testWidgets('shows the 3 steps in order', (tester) async {
      await show(tester, 0);

      final check = tester.getTopLeft(find.text('Checking card')).dy;
      final pay = tester.getTopLeft(find.text('Paying')).dy;
      final save = tester.getTopLeft(find.text('Saving order')).dy;

      expect(check, lessThan(pay));
      expect(pay, lessThan(save));
    });

    testWidgets('step 1 runs, the others wait', (tester) async {
      await show(tester, 0);

      expect(isRunning(0), isTrue);
      expect(isWaiting(1), isTrue);
      expect(isWaiting(2), isTrue);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('step 1 is done while step 2 runs', (tester) async {
      await show(tester, 1);

      expect(isDone(0), isTrue);
      expect(isRunning(1), isTrue);
      expect(isWaiting(2), isTrue);
    });

    testWidgets('step 3 runs after the first 2 are done', (tester) async {
      await show(tester, 2);

      expect(isDone(0), isTrue);
      expect(isDone(1), isTrue);
      expect(isRunning(2), isTrue);
    });

    testWidgets('all ticked, with no spinner, when done', (tester) async {
      await show(tester, 3);

      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('text colours show done, running and waiting',
        (tester) async {
      await show(tester, 1);

      Color? colorOf(String text) =>
          tester.widget<Text>(find.text(text)).style?.color;

      expect(colorOf('Checking card'), AppTheme.successGreen);
      expect(colorOf('Paying'), AppTheme.deepOrange);
      expect(colorOf('Saving order'), AppTheme.textMuted);
    });

    testWidgets('with Reduce animations, a still dot replaces the spinner',
        (tester) async {
      await show(tester, 1, reduceMotion: true);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        rowHas(1, find.byIcon(Icons.radio_button_checked_rounded)),
        isTrue,
      );
    });

    testWidgets('screen readers hear each step and its state',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, 1);

      expect(find.bySemanticsLabel('Checking card, done'), findsOneWidget);
      expect(find.bySemanticsLabel('Paying, now'), findsOneWidget);
      expect(find.bySemanticsLabel('Saving order, waiting'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a small phone has no overflow', (tester) async {
      await show(tester, 1, width: 960);

      expect(tester.takeException(), isNull);
    });
  });
}