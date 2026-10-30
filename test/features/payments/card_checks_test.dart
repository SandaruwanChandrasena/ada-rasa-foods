import 'package:ada_rasa_foods/features/payments/domain/card_brand.dart';
import 'package:ada_rasa_foods/features/payments/domain/card_checks.dart';
import 'package:ada_rasa_foods/features/payments/domain/payment_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The demo cards from the design.
  const visaOk = '4242 4242 4242 4242';
  const mastercardOk = '5555 5555 5555 4444';
  const visaFails = '4000 0000 0000 0002';

  final now = DateTime(2026, 10, 30);

  group('brandOf', () {
    test('a number starting with 4 is Visa, even while typing', () {
      expect(CardChecks.brandOf('4'), CardBrand.visa);
      expect(CardChecks.brandOf(visaOk), CardBrand.visa);
    });

    test('51 to 55 is Mastercard', () {
      expect(CardChecks.brandOf('51'), CardBrand.mastercard);
      expect(CardChecks.brandOf(mastercardOk), CardBrand.mastercard);
    });

    test('2221 to 2720 is Mastercard', () {
      expect(CardChecks.brandOf('2221'), CardBrand.mastercard);
      expect(CardChecks.brandOf('2720'), CardBrand.mastercard);
      expect(CardChecks.brandOf('2721'), isNull);
    });

    test('other cards and too few digits give no brand', () {
      expect(CardChecks.brandOf(''), isNull);
      expect(CardChecks.brandOf('5'), isNull);
      expect(CardChecks.brandOf('56'), isNull);
      expect(CardChecks.brandOf('6011 1111 1111 1117'), isNull);
    });
  });

  group('passesLuhn', () {
    test('the 3 demo cards pass', () {
      expect(CardChecks.passesLuhn(visaOk), isTrue);
      expect(CardChecks.passesLuhn(mastercardOk), isTrue);
      expect(CardChecks.passesLuhn(visaFails), isTrue);
    });

    test('one wrong digit fails', () {
      expect(CardChecks.passesLuhn('4242 4242 4242 4241'), isFalse);
    });

    test('an empty number fails', () {
      expect(CardChecks.passesLuhn(''), isFalse);
    });
  });

  group('numberError', () {
    test('good Visa and Mastercard numbers have no error', () {
      expect(CardChecks.numberError(visaOk), isNull);
      expect(CardChecks.numberError(mastercardOk), isNull);
      expect(CardChecks.numberError(visaFails), isNull);
    });

    test('an empty number asks for the number', () {
      expect(CardChecks.numberError(''), 'Enter the card number.');
    });

    test('too few or too many digits', () {
      expect(
        CardChecks.numberError('4242 4242 4242'),
        'The card number must have 16 digits.',
      );
      expect(
        CardChecks.numberError('4242 4242 4242 4242 4'),
        'The card number must have 16 digits.',
      );
    });

    test('another card type is refused', () {
      expect(
        CardChecks.numberError('6011 1111 1111 1117'),
        'Only Visa or Mastercard.',
      );
    });

    test('a number that fails Luhn is not valid', () {
      expect(
        CardChecks.numberError('4242 4242 4242 4241'),
        'This card number is not valid.',
      );
    });
  });

  group('nameError', () {
    test('a real name has no error', () {
      expect(CardChecks.nameError('Nimal Perera'), isNull);
    });

    test('an empty or 1-letter name asks for the name', () {
      expect(CardChecks.nameError(''), 'Enter the name on the card.');
      expect(CardChecks.nameError('  A  '), 'Enter the name on the card.');
    });
  });

  group('expiryError', () {
    test('this month and later months are ok', () {
      expect(CardChecks.expiryError('10/26', now), isNull);
      expect(CardChecks.expiryError('01/27', now), isNull);
    });

    test('last month has expired', () {
      expect(CardChecks.expiryError('09/26', now), 'This card has expired.');
      expect(CardChecks.expiryError('12/25', now), 'This card has expired.');
    });

    test('the month must be 01 to 12', () {
      expect(
        CardChecks.expiryError('13/27', now),
        'The month must be 01 to 12.',
      );
      expect(
        CardChecks.expiryError('00/27', now),
        'The month must be 01 to 12.',
      );
    });

    test('anything not MM/YY is refused', () {
      for (final input in ['', '1/27', '0127', '01/2027', 'ab/cd']) {
        expect(
          CardChecks.expiryError(input, now),
          'Enter the expiry as MM/YY.',
          reason: input,
        );
      }
    });

    test('parseExpiry gives the month and a 4-digit year', () {
      expect(CardChecks.parseExpiry('08/28'), (8, 2028));
      expect(CardChecks.parseExpiry('8/28'), isNull);
    });
  });

  group('cvvError', () {
    test('3 digits is ok', () {
      expect(CardChecks.cvvError('123'), isNull);
    });

    test('anything else is refused', () {
      for (final input in ['', '12', '1234', '12a']) {
        expect(
          CardChecks.cvvError(input),
          'The CVV must have 3 digits.',
          reason: input,
        );
      }
    });
  });

  group('formatNumber and last4Of', () {
    test('formatNumber makes groups of 4, even while typing', () {
      expect(CardChecks.formatNumber('4242424242424242'), visaOk);
      expect(CardChecks.formatNumber('42424'), '4242 4');
      expect(CardChecks.formatNumber(''), '');
    });

    test('last4Of keeps only the last 4 digits', () {
      expect(CardChecks.last4Of(visaOk), '4242');
      expect(CardChecks.last4Of(visaFails), '0002');
    });
  });

  group('PaymentCard', () {
    const card = PaymentCard(
      brand: CardBrand.visa,
      last4: '4242',
      holderName: 'Nimal Perera',
      expMonth: 8,
      expYear: 2028,
    );

    PaymentCard withExpiry(int month, int year, {String last4 = '4242'}) {
      return PaymentCard(
        brand: CardBrand.visa,
        last4: last4,
        holderName: 'Nimal Perera',
        expMonth: month,
        expYear: year,
      );
    }

    test('expiryText and title read well', () {
      expect(card.expiryText, '08/28');
      expect(card.title, 'Visa ending 4242');
    });

    test('a card works until the end of its expiry month', () {
      expect(withExpiry(10, 2026).isExpired(now), isFalse);
      expect(withExpiry(9, 2026).isExpired(now), isTrue);
      expect(withExpiry(1, 2027).isExpired(now), isFalse);
    });

    test('only the card ending in 0002 always fails', () {
      expect(card.alwaysFails, isFalse);
      expect(withExpiry(8, 2028, last4: '0002').alwaysFails, isTrue);
    });

    test('the same type, last 4, and expiry is the same card', () {
      const sameButNewName = PaymentCard(
        id: 'c2',
        brand: CardBrand.visa,
        last4: '4242',
        holderName: 'Someone Else',
        expMonth: 8,
        expYear: 2028,
      );

      expect(card.isSameCardAs(sameButNewName), isTrue);
      expect(card.isSameCardAs(withExpiry(9, 2028)), isFalse);
      expect(card.isSameCardAs(withExpiry(8, 2028, last4: '1111')), isFalse);
    });
  });
}