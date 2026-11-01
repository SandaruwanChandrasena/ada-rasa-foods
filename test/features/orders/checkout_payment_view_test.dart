import 'package:ada_rasa_foods/features/orders/presentation/checkout_payment_view.dart';
import 'package:ada_rasa_foods/features/orders/presentation/checkout_state.dart';
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

CheckoutState checkoutWith(CheckoutStatus status) =>
    CheckoutState(status: status);

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
        cardPaymentStageOf(
          paymentWith(DemoPaymentStatus.processing),
          checkoutWith(CheckoutStatus.ready),
        ),
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
        cardPaymentStageOf(
          paymentWith(DemoPaymentStatus.approved),
          checkoutWith(CheckoutStatus.placed),
        ),
        CardPaymentStage.success,
      );
    });

    test('failed when the order could not be saved', () {
      expect(
        cardPaymentStageOf(
          paymentWith(DemoPaymentStatus.approved),
          checkoutWith(CheckoutStatus.failure),
        ),
        CardPaymentStage.failed,
      );
    });

    test('declined for the 0002 card', () {
      expect(
        cardPaymentStageOf(
          paymentWith(DemoPaymentStatus.declined),
          checkoutWith(CheckoutStatus.ready),
        ),
        CardPaymentStage.declined,
      );
    });
  });

  group('CheckoutPaymentView', () {
    late ValueNotifier<CardPaymentStage> stage;
    late int viewOrder;
    late int tryAgain;
    late int tryAnother;
    late int backToCart;

    setUp(() {
      stage = ValueNotifier(CardPaymentStage.processing);
      viewOrder = 0;
      tryAgain = 0;
      tryAnother = 0;
      backToCart = 0;
    });

    Future<void> show(
      WidgetTester tester,
      CardPaymentStage first, {
      String? errorMessage,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      stage.value = first;
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<CardPaymentStage>(
            valueListenable: stage,
            builder: (context, value, _) => CheckoutPaymentView(
              stage: value,
              card: visa,
              amount: 2400,
              errorMessage: errorMessage,
              onViewOrder: () => viewOrder++,
              onTryAgain: () => tryAgain++,
              onTryAnotherCard: () => tryAnother++,
              onBackToCart: () => backToCart++,
            ),
          ),
        ),
      );
    }

    testWidgets('processing shows the card, amount, and no buttons',
        (tester) async {
      await show(tester, CardPaymentStage.processing);

      expect(find.text('Processing payment...'), findsOneWidget);
      expect(find.text('Visa ending 4242'), findsOneWidget);
      expect(find.text('Rs. 2,400'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('every step shows the demo note', (tester) async {
      for (final value in CardPaymentStage.values) {
        await show(tester, value);
        expect(
          find.text('Demo payment, no real charge.'),
          findsOneWidget,
          reason: '$value',
        );
      }
      // Ends the success timer, so the test can finish.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('success shows the paid amount and card', (tester) async {
      await show(tester, CardPaymentStage.success);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Payment successful'), findsOneWidget);
      expect(
        find.text('Rs. 2,400 paid with Visa ending 4242'),
        findsOneWidget,
      );
      expect(find.text('View order'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('success opens the order by itself after 1.5 s',
        (tester) async {
      await show(tester, CardPaymentStage.success);

      await tester.pump(const Duration(milliseconds: 1400));
      expect(viewOrder, 0);

      await tester.pump(const Duration(milliseconds: 200));
      expect(viewOrder, 1);
    });

    testWidgets('View order opens it at once, and only once',
        (tester) async {
      await show(tester, CardPaymentStage.success);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('View order'));
      expect(viewOrder, 1);

      // The timer must not open it a second time.
      await tester.pump(const Duration(seconds: 2));
      expect(viewOrder, 1);
    });

    testWidgets('processing then success starts the 1.5 s timer',
        (tester) async {
      await show(tester, CardPaymentStage.processing);
      await tester.pump(const Duration(seconds: 2));
      expect(viewOrder, 0);

      stage.value = CardPaymentStage.success;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));

      expect(find.text('Payment successful'), findsOneWidget);
      expect(viewOrder, 1);
    });

    testWidgets('leaving before 1.5 s does not open the order',
        (tester) async {
      await show(tester, CardPaymentStage.success);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));

      expect(viewOrder, 0);
    });

    testWidgets('declined shows the message and two buttons',
        (tester) async {
      await show(tester, CardPaymentStage.declined);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Payment declined'), findsOneWidget);
      expect(find.text('Your card was declined (demo).'), findsOneWidget);
      expect(find.text('No order was placed.'), findsOneWidget);

      await tester.tap(find.text('Try another card'));
      await tester.tap(find.text('Back to cart'));

      expect(tryAnother, 1);
      expect(backToCart, 1);
      expect(viewOrder, 0);
    });

    testWidgets('failed shows the reason and "no money was taken"',
        (tester) async {
      await show(
        tester,
        CardPaymentStage.failed,
        errorMessage: 'Kottu Corner is not taking orders now.',
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Payment not done'), findsOneWidget);
      expect(
        find.text('Kottu Corner is not taking orders now.'),
        findsOneWidget,
      );
      expect(find.text('No money was taken (demo).'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.tap(find.text('Back to cart'));

      expect(tryAgain, 1);
      expect(backToCart, 1);
    });

    testWidgets('with animations off, the icon shows at once',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: CheckoutPaymentView(
                stage: CardPaymentStage.declined,
                card: visa,
                amount: 2400,
                onViewOrder: () {},
                onTryAgain: () {},
                onTryAnotherCard: () {},
                onBackToCart: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Payment declined'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}