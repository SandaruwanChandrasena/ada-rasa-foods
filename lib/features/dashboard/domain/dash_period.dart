// The dashboard period switch: Today, 7 days or 30 days.
enum DashPeriod {
  today('Today', 1, 3),
  week('7 days', 7, 5),
  month('30 days', 30, 5);

  const DashPeriod(this.label, this.days, this.maxTopDishes);

  final String label;

  // Today counts as one of the days.
  final int days;
  final int maxTopDishes;

  // The longest period. The dashboard loads this much once.
  static const longest = DashPeriod.month;

  // Midnight on the first day of the period.
  DateTime since(DateTime now) {
    return DateTime(now.year, now.month, now.day - (days - 1));
  }
}