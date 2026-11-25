import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/features/orders/presentation/checkout_payment_view.dart';
import 'package:ada_rasa_foods/features/orders/presentation/checkout_state.dart';
import 'package:ada_rasa_foods/features/orders/presentation/payment_steps.dart';
import 'package:ada_rasa_foods/features/payments/domain/card_brand.dart';
import 'package:ada_rasa_foods/features/payments/domain/payment_card.dart';
import 'package:ada_rasa_foods/features/payments/presentation/payment_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const visa = PaymentCard(
  id: 'c1',
  brand: CardBrand.visa,
  last4: '4242',
  holderName: 'NIMAL PERERA',
  expMonth: 8,
  expYear: 2030,
);

PaymentState paymentWith(DemoPaymentStatus status) =>
    PaymentState(status: status, card: visa, amount: 2400);

CheckoutState checkoutWith(CheckoutStatus status, {String? error}) =>
    CheckoutState(status: status, errorMessage: error);

typedef Screen = (PaymentState, CheckoutState);

final Screen paying = (
  paymentWith(DemoPaymentStatus.processing),
  checkoutWith(CheckoutStatus.ready),
);
final Screen saving = (
  paymentWith(DemoPaymentStatus.approved),
  checkoutWith(CheckoutStatus.placing),
);
final Screen success = (
  paymentWith(DemoPaymentStatus.approved),
  checkoutWith(CheckoutStatus.placed),
);
final Screen declined = (
  paymentWith(DemoPaymentStatus.declined),
  checkoutWith(CheckoutStatus.ready),
);
final Screen failed = (
  paymentWith(DemoPaymentStatus.approved),
  checkoutWith(
    CheckoutStatus.failure,
    error: 'Kottu Corner is not taking orders now.',
  ),
);

Finder stepRow(int index) => find.byKey(ValueKey('payment_step_$index'));

bool isDone(int index) => find
    .descendant(
      of: stepRow(index),
      matching: find.byIcon(Icons.check_circle_rounded),
    )
    .evaluate()
    .isNotEmpty;

bool isRunning(int index) => find
    .descendant(
      of: stepRow(index),
      matching: find.byType(CircularProgressIndicator),
    )
    .evaluate()
    .isNotEmpty;

// A soft circle behind the big icon, found by its colour.
Finder softCircle(Color color) => find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color == color &&
          (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
    );

void main() {
  group('cardPaymentStageOf', () {
    test('no cover before a card payment starts', () {
      expect(
        cardPaymentStageOf(
          const PaymentState(),
          checkoutWith(CheckoutStatus.ready),
        ),
        isNull,
      );
    });

    test('processing while the 2 seconds run', () {
      expect(
        cardPaymentStageOf(paying.$1, paying.$2),
        CardPaymentStage.processing,
      );
    });

    test('still processing while the order is being saved', () {
      final payment = paymentWith(DemoPaymentStatus.approved);
      expect(
        cardPaymentStageOf(payment, checkoutWith(CheckoutStatus.ready)),
        CardPaymentStage.processing,
      );
      expect(
        cardPaymentStageOf(payment, checkoutWith(CheckoutStatus.placing)),
        CardPaymentStage.processing,
      );
    });

    test('success only after the order is saved', () {
      expect(
        cardPaymentStageOf(success.$1, success.$2),
        CardPaymentStage.success,
      );
    });

    test('failed when the order could not be saved', () {
      expect(
        cardPaymentStageOf(failed.$1, failed.$2),
        CardPaymentStage.failed,
      );
    });

    test('declined for the 0002 card', () {
      expect(
        cardPaymentStageOf(declined.$1, declined.$2),
        CardPaymentStage.declined,
      );
    });
  });

  group('CheckoutPaymentView', () {
    late ValueNotifier<Screen> screen;
    late int viewOrder;
    late int tryAgain;
    late int tryAnother;
    late int backToCart;

    setUp(() {
      screen = ValueNotifier(paying);
      viewOrder = 0;
      tryAgain = 0;
      tryAnother = 0;
      backToCart = 0;
    });

    Future<void> show(
      WidgetTester tester,
      Screen first, {
      bool reduceMotion = false,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      screen.value = first;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: reduceMotion,
              ),
              child: ValueListenableBuilder<Screen>(
                valueListenable: screen,
                builder: (context, value, _) => CheckoutPaymentView(
                  payment: value.$1,
                  checkout: value.$2,
                  onViewOrder: () => viewOrder++,
                  onTryAgain: () => tryAgain++,
                  onTryAnotherCard: () => tryAnother++,
                  onBackToCart: () => backToCart++,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Removes the screen, so no timer is left running.
    Future<void> finish(WidgetTester tester) =>
        tester.pumpWidget(const SizedBox());

    testWidgets('processing shows the card, amount, steps, and no buttons',
        (tester) async {
      await show(tester, paying);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Processing payment'), findsOneWidget);
      expect(find.text('Rs. 2,400'), findsOneWidget);
      expect(find.byType(PaymentSteps), findsOneWidget);
      expect(isRunning(0), isTrue);
      expect(find.byType(FilledButton), findsNothing);
      await finish(tester);
    });

    testWidgets('"Paying" runs after the card is checked', (tester) async {
      await show(tester, paying);

      await tester.pump(const Duration(milliseconds: 700));
      expect(isRunning(0), isTrue);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 300));
      expect(isDone(0), isTrue);
      expect(isRunning(1), isTrue);
      await finish(tester);
    });

    testWidgets('"Saving order" runs while the order is saved',
        (tester) async {
      await show(tester, paying);
      await tester.pump(const Duration(seconds: 1));

      screen.value = saving;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(isDone(0), isTrue);
      expect(isDone(1), isTrue);
      expect(isRunning(2), isTrue);
      expect(find.text('Processing payment'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('every screen shows the demo note', (tester) async {
      for (final value in [paying, success, declined, failed]) {
        await show(tester, value);
        expect(
          find.text('Demo payment, no real charge.'),
          findsOneWidget,
          reason: '$value',
        );
      }
      await finish(tester);
    });

    testWidgets('success shows the amount, card, and 3 ticked steps',
        (tester) async {
      await show(tester, success);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Payment successful'), findsOneWidget);
      expect(find.text('Rs. 2,400 · Visa ending 4242'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
      expect(find.text('View order'), findsOneWidget);
      expect(find.text('Opens by itself'), findsOneWidget);
      expect(softCircle(AppTheme.successBg), findsOneWidget);
      await finish(tester);
    });

    testWidgets('success opens the order by itself after 1.5 s',
        (tester) async {
      await show(tester, success);

      await tester.pump(const Duration(milliseconds: 1400));
      expect(viewOrder, 0);

      await tester.pump(const Duration(milliseconds: 200));
      expect(viewOrder, 1);
    });

    testWidgets('View order opens it at once, and only once',
        (tester) async {
      await show(tester, success);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('View order'));
      expect(viewOrder, 1);

      // The timer must not open it a second time.
      await tester.pump(const Duration(seconds: 2));
      expect(viewOrder, 1);
    });

    testWidgets('processing then success starts the 1.5 s timer',
        (tester) async {
      await show(tester, paying);
      await tester.pump(const Duration(seconds: 2));
      expect(viewOrder, 0);

      screen.value = success;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));

      expect(find.text('Payment successful'), findsOneWidget);
      expect(viewOrder, 1);
    });

    testWidgets('leaving before 1.5 s does not open the order',
        (tester) async {
      await show(tester, success);
      await tester.pump(const Duration(milliseconds: 500));

      await finish(tester);
      await tester.pump(const Duration(seconds: 2));

      expect(viewOrder, 0);
    });

    testWidgets('declined shows a red X, one line and two buttons',
        (tester) async {
      await show(tester, declined);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Payment declined'), findsOneWidget);
      expect(find.text('No order was placed.'), findsOneWidget);
      expect(find.byType(PaymentSteps), findsNothing);
      expect(softCircle(AppTheme.dangerBg), findsOneWidget);

      await tester.tap(find.text('Try another card'));
      await tester.tap(find.text('Back to cart'));

      expect(tryAnother, 1);
      expect(backToCart, 1);
      expect(viewOrder, 0);
    });

    testWidgets('failed shows the reason and "no money was taken"',
        (tester) async {
      await show(tester, failed);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Payment not done'), findsOneWidget);
      expect(
        find.text('Kottu Corner is not taking orders now.'),
        findsOneWidget,
      );
      expect(find.text('No money was taken (demo).'), findsOneWidget);
      expect(find.byType(PaymentSteps), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.tap(find.text('Back to cart'));

      expect(tryAgain, 1);
      expect(backToCart, 1);
    });

    testWidgets('paying again after a fail starts the steps over',
        (tester) async {
      await show(tester, paying);
      await tester.pump(const Duration(seconds: 1));
      expect(isRunning(1), isTrue);

      screen.value = failed;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      screen.value = paying;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(isRunning(0), isTrue);

      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 300));
      expect(isRunning(1), isTrue);
      await finish(tester);
    });

    testWidgets('with animations off, the icon shows at once',
        (tester) async {
      await show(tester, declined, reduceMotion: true);
      await tester.pump();

      expect(find.text('Payment declined'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}