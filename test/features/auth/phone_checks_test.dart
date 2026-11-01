import 'package:ada_rasa_foods/features/auth/domain/phone_checks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('error', () {
    test('a good number has no error', () {
      expect(PhoneChecks.error('0712345678'), isNull);
    });

    test('spaces and dashes are allowed', () {
      expect(PhoneChecks.error('071 234 5678'), isNull);
      expect(PhoneChecks.error('071-234-5678'), isNull);
      expect(PhoneChecks.error('  0712345678  '), isNull);
    });

    test('an empty number asks for one', () {
      expect(PhoneChecks.error(''), 'Please enter your phone number.');
      expect(PhoneChecks.error('   '), 'Please enter your phone number.');
    });

    test('letters and other symbols are refused', () {
      expect(PhoneChecks.error('07a2345678'), 'Use only numbers.');
      expect(PhoneChecks.error('+94712345678'), 'Use only numbers.');
    });

    test('it must start with 07', () {
      expect(
        PhoneChecks.error('0112345678'),
        'A mobile number starts with 07.',
      );
      expect(
        PhoneChecks.error('7123456789'),
        'A mobile number starts with 07.',
      );
    });

    test('it must have exactly 10 digits', () {
      expect(
        PhoneChecks.error('071234567'),
        'A mobile number has 10 digits.',
      );
      expect(
        PhoneChecks.error('07123456789'),
        'A mobile number has 10 digits.',
      );
    });
  });

  test('isValid matches error', () {
    expect(PhoneChecks.isValid('077 123 4567'), isTrue);
    expect(PhoneChecks.isValid('12345'), isFalse);
  });

  test('digitsOnly keeps only the digits', () {
    expect(PhoneChecks.digitsOnly('071 234-5678'), '0712345678');
  });

  group('format', () {
    test('shows a saved number in groups', () {
      expect(PhoneChecks.format('0712345678'), '071 234 5678');
    });

    test('a typed number with spaces gives the same result', () {
      expect(PhoneChecks.format('071-2345 678'), '071 234 5678');
    });

    test('a wrong length comes back as it is', () {
      expect(PhoneChecks.format('12345'), '12345');
      expect(PhoneChecks.format(''), '');
    });
  });
}