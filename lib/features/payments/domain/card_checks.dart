import 'card_brand.dart';

// Checks for the Add card form (CUS-9). Each error is a short message.
class CardChecks {
  CardChecks._();

  static const int numberLength = 16;

  // Keeps only the digits, so "4242 4242" becomes "42424242".
  static String digitsOnly(String input) =>
      input.replaceAll(RegExp(r'[^0-9]'), '');

  // Works while typing, so the card preview can show the logo early.
  static CardBrand? brandOf(String input) {
    final digits = digitsOnly(input);
    if (digits.startsWith('4')) return CardBrand.visa;

    if (digits.length >= 2) {
      final firstTwo = int.parse(digits.substring(0, 2));
      if (firstTwo >= 51 && firstTwo <= 55) return CardBrand.mastercard;
    }
    // Newer Mastercards start with 2221 to 2720.
    if (digits.length >= 4) {
      final firstFour = int.parse(digits.substring(0, 4));
      if (firstFour >= 2221 && firstFour <= 2720) {
        return CardBrand.mastercard;
      }
    }
    return null;
  }

  // The Luhn check finds most typing mistakes in a card number.
  static bool passesLuhn(String input) {
    final digits = digitsOnly(input);
    if (digits.isEmpty) return false;

    var sum = 0;
    var doubleIt = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var digit = int.parse(digits[i]);
      if (doubleIt) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      doubleIt = !doubleIt;
    }
    return sum % 10 == 0;
  }

  static String? numberError(String input) {
    final digits = digitsOnly(input);
    if (digits.isEmpty) return 'Enter the card number.';
    if (digits.length != numberLength) {
      return 'The card number must have 16 digits.';
    }
    if (brandOf(digits) == null) return 'Only Visa or Mastercard.';
    if (!passesLuhn(digits)) return 'This card number is not valid.';
    return null;
  }

  static String? nameError(String input) {
    if (input.trim().length < 2) return 'Enter the name on the card.';
    return null;
  }

  // The expiry is typed as MM/YY, like "08/28".
  static String? expiryError(String input, DateTime now) {
    final expiry = parseExpiry(input);
    if (expiry == null) return 'Enter the expiry as MM/YY.';

    final (month, year) = expiry;
    if (month < 1 || month > 12) return 'The month must be 01 to 12.';
    if (year < now.year || (year == now.year && month < now.month)) {
      return 'This card has expired.';
    }
    return null;
  }

  // Gives (month, 4-digit year), or null if it is not MM/YY.
  static (int, int)? parseExpiry(String input) {
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(input.trim());
    if (match == null) return null;
    return (int.parse(match.group(1)!), 2000 + int.parse(match.group(2)!));
  }

  static String? cvvError(String input) {
    if (!RegExp(r'^\d{3}$').hasMatch(input)) {
      return 'The CVV must have 3 digits.';
    }
    return null;
  }

  // Groups of 4 for the preview, like "4242 4242 4242 4242".
  static String formatNumber(String input) {
    final digits = digitsOnly(input);
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  // Only these 4 digits are saved, never the full number.
  static String last4Of(String input) {
    final digits = digitsOnly(input);
    return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
  }
}