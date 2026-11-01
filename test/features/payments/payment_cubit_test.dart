import 'package:ada_rasa_foods/features/payments/domain/card_brand.dart';
import 'package:ada_rasa_foods/features/payments/domain/payment_card.dart';
import 'package:ada_rasa_foods/features/payments/presentation/payment_cubit.dart';
import 'package:ada_rasa_foods/features/payments/presentation/payment_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

const visa = PaymentCard(
  id: 'c1',
  brand: CardBrand.visa,
  last4: '4242',
  holderName: 'NIMAL PERERA',
  expMonth: 8,
  expYear: 2030,
  isDefault: true,
);

const failing = PaymentCard(
  id: 'c2',
  brand: CardBrand.visa,
  last4: '0002',
  holderName: 'NIMAL PERERA',
  expMonth: 8,
  expYear: 2030,
);

const processingVisa = PaymentState(
  status: DemoPaymentStatus.processing,
  card: visa,
  amount: 2400,
);

const approvedVisa = PaymentState(
  status: DemoPaymentStatus.approved,
  card: visa,
  amount: 2400,
);

const processingFailing = PaymentState(
  status: DemoPaymentStatus.processing,
  card: failing,
  amount: 2400,
);

const declinedFailing = PaymentState(
  status: DemoPaymentStatus.declined,
  card: failing,
  amount: 2400,
);

// No waiting in most tests.
PaymentCubit build() => PaymentCubit(processingTime: Duration.zero);

void main() {
  test('starts idle', () {
    expect(build().state, const PaymentState());
  });

  test('waits 2 seconds by default', () {
    expect(PaymentCubit.defaultProcessingTime, const Duration(seconds: 2));
  });

  blocTest<PaymentCubit, PaymentState>(
    'a good card goes processing, then approved',
    build: build,
    act: (cubit) => cubit.pay(card: visa, amount: 2400),
    expect: () => const [processingVisa, approvedVisa],
  );

  blocTest<PaymentCubit, PaymentState>(
    'the card ending 0002 goes processing, then declined',
    build: build,
    act: (cubit) => cubit.pay(card: failing, amount: 2400),
    expect: () => const [processingFailing, declinedFailing],
  );

  test('pay gives true for a good card and false for 0002', () async {
    final cubit = build();
    expect(await cubit.pay(card: visa, amount: 2400), isTrue);

    final other = build();
    expect(await other.pay(card: failing, amount: 2400), isFalse);

    await cubit.close();
    await other.close();
  });

  test('stays processing until the processing time is over', () async {
    final cubit = PaymentCubit(
      processingTime: const Duration(milliseconds: 80),
    );

    final result = cubit.pay(card: visa, amount: 2400);
    expect(cubit.state, processingVisa);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state, processingVisa);

    expect(await result, isTrue);
    expect(cubit.state, approvedVisa);
    await cubit.close();
  });

  blocTest<PaymentCubit, PaymentState>(
    'a fast second tap does not start a second payment',
    build: build,
    act: (cubit) async {
      final first = cubit.pay(card: visa, amount: 2400);
      final second = await cubit.pay(card: visa, amount: 2400);
      expect(second, isFalse);
      await first;
    },
    expect: () => const [processingVisa, approvedVisa],
  );

  blocTest<PaymentCubit, PaymentState>(
    'can try another card after a decline',
    build: build,
    act: (cubit) async {
      await cubit.pay(card: failing, amount: 2400);
      cubit.reset();
      await cubit.pay(card: visa, amount: 2400);
    },
    expect: () => const [
      processingFailing,
      declinedFailing,
      PaymentState(),
      processingVisa,
      approvedVisa,
    ],
  );

  blocTest<PaymentCubit, PaymentState>(
    'reset does nothing while processing',
    build: build,
    act: (cubit) async {
      final payment = cubit.pay(card: visa, amount: 2400);
      cubit.reset();
      await payment;
    },
    expect: () => const [processingVisa, approvedVisa],
  );

  blocTest<PaymentCubit, PaymentState>(
    'reset does nothing when already idle',
    build: build,
    act: (cubit) => cubit.reset(),
    expect: () => const <PaymentState>[],
  );

  test('closing the screen while processing gives no error', () async {
    final cubit = PaymentCubit(
      processingTime: const Duration(milliseconds: 30),
    );

    final result = cubit.pay(card: visa, amount: 2400);
    await cubit.close();

    expect(await result, isFalse);
  });
}