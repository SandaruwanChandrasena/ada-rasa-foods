import 'package:ada_rasa_foods/core/utils/price_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPrice', () {
    test('small price has no comma', () {
      expect(formatPrice(0), 'Rs. 0');
      expect(formatPrice(950), 'Rs. 950');
    });

    test('adds a comma for thousands', () {
      expect(formatPrice(1200), 'Rs. 1,200');
      expect(formatPrice(100000), 'Rs. 100,000');
    });

    test('adds a comma for every 3 digits', () {
      expect(formatPrice(1234567), 'Rs. 1,234,567');
    });

    test('keeps the minus sign', () {
      expect(formatPrice(-1500), 'Rs. -1,500');
    });
  });
}