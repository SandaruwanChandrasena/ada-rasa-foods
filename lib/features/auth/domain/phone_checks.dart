// Checks for a Sri Lankan mobile number, like 071 234 5678.
// The restaurant uses it to call the customer about an order.
class PhoneChecks {
  PhoneChecks._();

  static const int length = 10;

  // Keeps only the digits, so "071 234 5678" becomes "0712345678".
  static String digitsOnly(String input) =>
      input.replaceAll(RegExp(r'[^0-9]'), '');

  // Null means the number is fine. Spaces and dashes are allowed.
  static String? error(String input) {
    final text = input.trim();
    if (text.isEmpty) return 'Please enter your phone number.';
    if (RegExp(r'[^0-9 \-]').hasMatch(text)) {
      return 'Use only numbers.';
    }

    final digits = digitsOnly(text);
    if (!digits.startsWith('07')) return 'A mobile number starts with 07.';
    if (digits.length != length) return 'A mobile number has 10 digits.';
    return null;
  }

  static bool isValid(String input) => error(input) == null;

  // Shows a saved number as "071 234 5678". Other text comes back as it is.
  static String format(String input) {
    final digits = digitsOnly(input);
    if (digits.length != length) return input;
    return '${digits.substring(0, 3)} ${digits.substring(3, 6)} '
        '${digits.substring(6)}';
  }
}