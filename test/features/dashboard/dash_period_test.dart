import 'package:ada_rasa_foods/features/dashboard/domain/dash_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 28, 0, 17);

  test('the switch shows Today, 7 days and 30 days in order', () {
    expect(DashPeriod.values.map((p) => p.label), [
      'Today',
      '7 days',
      '30 days',
    ]);
  });

  test('Today starts at midnight today', () {
    expect(DashPeriod.today.since(now), DateTime(2026, 11, 28));
  });

  test('7 days starts 6 days before today', () {
    expect(DashPeriod.week.since(now), DateTime(2026, 11, 22));
  });

  test('30 days goes back into the last month', () {
    expect(DashPeriod.month.since(now), DateTime(2026, 10, 30));
  });

  test('Today shows 3 top dishes, the others show 5', () {
    expect(DashPeriod.today.maxTopDishes, 3);
    expect(DashPeriod.week.maxTopDishes, 5);
    expect(DashPeriod.month.maxTopDishes, 5);
  });

  test('the longest period is 30 days', () {
    expect(DashPeriod.longest, DashPeriod.month);
  });
}