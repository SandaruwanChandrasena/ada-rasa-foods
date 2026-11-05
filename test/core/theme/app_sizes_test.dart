import 'package:ada_rasa_foods/core/theme/app_sizes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppIconSizes.forWidth', () {
    test('a phone under 360 wide gets the small sizes', () {
      final sizes = AppIconSizes.forWidth(320);

      expect(sizes.bar, 24);
      expect(sizes.body, 24);
    });

    test('359.9 is still small', () {
      expect(AppIconSizes.forWidth(359.9), same(AppIconSizes.small));
    });

    test('exactly 360 wide gets the normal sizes', () {
      final sizes = AppIconSizes.forWidth(360);

      expect(sizes.bar, 26);
      expect(sizes.body, 25);
    });

    test('a 393 wide phone is normal', () {
      expect(AppIconSizes.forWidth(392.7), same(AppIconSizes.normal));
    });

    test('399.9 is still normal', () {
      expect(AppIconSizes.forWidth(399.9), same(AppIconSizes.normal));
    });

    test('exactly 400 wide gets the large sizes', () {
      final sizes = AppIconSizes.forWidth(400);

      expect(sizes.bar, 28);
      expect(sizes.body, 26);
    });

    test('a tablet is large', () {
      expect(AppIconSizes.forWidth(800), same(AppIconSizes.large));
    });
  });
}