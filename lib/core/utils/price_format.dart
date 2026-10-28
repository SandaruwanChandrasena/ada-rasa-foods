// Turns a whole rupee amount into text like "Rs. 1,200".
String formatPrice(int rupees) {
  final digits = rupees.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    // Add a comma before every group of 3 digits, counted from the right.
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  final sign = rupees < 0 ? '-' : '';
  return 'Rs. $sign$buffer';
}