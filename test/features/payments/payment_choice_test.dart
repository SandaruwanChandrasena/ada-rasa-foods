import 'package:ada_rasa_foods/features/payments/domain/card_brand.dart';
import 'package:ada_rasa_foods/features/payments/domain/payment_card.dart';
import 'package:ada_rasa_foods/features/payments/domain/payment_choice.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentCard card(
  String id,
  String last4, {
  bool isDefault = false,
  int expMonth = 8,
  int expYear = 2030,
}) {
  return PaymentCard(
    id: id,
    brand: CardBrand.visa,
    last4: last4,
    holderName: 'NIMAL PERERA',
    expMonth: expMonth,
    expYear: expYear,
    isDefault: isDefault,
  );
}

void main() {
  final now = DateTime(2026, 11, 1);

  final visa = card('c1', '4242', isDefault: true);
  final other = card('c2', '1111');
  final failing = card('c3', '0002');
  final expired = card('c4', '5555', expMonth: 9, expYear: 2026);
  final expiredDefault =
      card('c5', '4444', isDefault: true, expMonth: 9, expYear: 2026);

  group('before the customer picks', () {
    test('the default card is chosen', () {
      const choice = PaymentChoice();
      expect(choice.cardFrom([visa, other], now), visa);
    });

    test('cash is chosen when there are no cards', () {
      const choice = PaymentChoice();
      expect(choice.cardFrom([], now), isNull);
    });

    test('cash is chosen when the default card has expired', () {
      const choice = PaymentChoice();
      expect(choice.cardFrom([expiredDefault, other], now), isNull);
    });
  });

  group('after the customer picks', () {
    test('cash stays cash, even with a default card', () {
      const choice = PaymentChoice.cash();
      expect(choice.isCash, isTrue);
      expect(choice.cardFrom([visa, other], now), isNull);
    });

    test('a picked card stays picked', () {
      final choice = PaymentChoice.card(other);
      expect(choice.cardFrom([visa, other], now), other);
    });

    test('the 0002 card can be picked (for the fail demo)', () {
      final choice = PaymentChoice.card(failing);
      expect(choice.cardFrom([visa, failing], now), failing);
    });

    test('a deleted card falls back to the default card', () {
      final choice = PaymentChoice.card(other);
      expect(choice.cardFrom([visa], now), visa);
    });

    test('a deleted card falls back to cash when there is no default', () {
      final choice = PaymentChoice.card(other);
      expect(choice.cardFrom([failing], now), isNull);
    });

    test('an expired card is never used', () {
      final choice = PaymentChoice.card(expired);
      expect(choice.cardFrom([visa, expired], now), visa);
    });
  });

  group('expiry edge', () {
    test('a card works until the end of its expiry month', () {
      final lastMonth = card(
        'c6',
        '9999',
        isDefault: true,
        expMonth: 11,
        expYear: 2026,
      );
      const choice = PaymentChoice();
      expect(choice.cardFrom([lastMonth], DateTime(2026, 11, 30)), lastMonth);
      expect(choice.cardFrom([lastMonth], DateTime(2026, 12, 1)), isNull);
    });
  });

  group('newCard', () {
    test('finds the card that was not there before', () {
      final found = PaymentChoice.newCard([visa, other], {'c1'}, now);
      expect(found, other);
    });

    test('gives null when nothing is new', () {
      final found = PaymentChoice.newCard([visa], {'c1'}, now);
      expect(found, isNull);
    });

    test('skips a new card that has expired', () {
      final found = PaymentChoice.newCard([visa, expired], {'c1'}, now);
      expect(found, isNull);
    });

    test('with no cards before, the first card is new', () {
      final found = PaymentChoice.newCard([visa], {}, now);
      expect(found, visa);
    });
  });

  test('two choices with the same card are equal', () {
    expect(PaymentChoice.card(visa), PaymentChoice.card(visa));
    expect(const PaymentChoice.cash(), isNot(const PaymentChoice()));
  });
}