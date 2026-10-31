import 'package:flutter/services.dart';

import '../domain/card_checks.dart';

// Input rules for the Add card form. They run on every key press.

// Digits only, max 16, with a space after every 4.
class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = CardChecks.digitsOnly(newValue.text);
    if (digits.length > CardChecks.numberLength) {
      digits = digits.substring(0, CardChecks.numberLength);
    }
    final formatted = CardChecks.formatNumber(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// Letters, spaces, dot, apostrophe, and hyphen. Capitals, max 26.
class CardNameFormatter extends TextInputFormatter {
  // Real cards fit about 26 letters for the name.
  static const int maxLength = 26;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var cleaned = newValue.text.replaceAll(RegExp(r"[^a-zA-Z\s.'-]"), '');
    if (cleaned.length > maxLength) cleaned = cleaned.substring(0, maxLength);
    cleaned = cleaned.toUpperCase();
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}

// Digits only, max 3. Visa and Mastercard have a 3-digit CVV.
class CvvFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = CardChecks.digitsOnly(newValue.text);
    if (digits.length > 3) digits = digits.substring(0, 3);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}