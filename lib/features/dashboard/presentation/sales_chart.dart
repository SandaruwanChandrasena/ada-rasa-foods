import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';

// Seven simple bars: sales of the last 7 days, today last and orange.
// Drawn with boxes, so no chart package is needed.
class WeekSalesChart extends StatelessWidget {
  const WeekSalesChart({
    super.key,
    required this.sales,
    required this.today,
  });

  static const double barsHeight = 90;

  // An empty day still shows a thin bar.
  static const double minBar = 4;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // Today last.
  final List<int> sales;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final most = sales.fold(0, (max, v) => v > max ? v : max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < sales.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _bar(i, most)),
        ],
      ],
    );
  }

  Widget _bar(int index, int most) {
    final isToday = index == sales.length - 1;
    final day = DateTime(
      today.year,
      today.month,
      today.day - (sales.length - 1 - index),
    );
    final value = sales[index];
    final height = most == 0
        ? minBar
        : (value / most * barsHeight).clamp(minBar, barsHeight).toDouble();
    final color = isToday
        ? AppTheme.brandOrange
        : AppTheme.brandOrange.withValues(alpha: 0.28);

    // container: each bar is its own node, so labels never merge.
    return Semantics(
      container: true,
      label: '${_names[day.weekday - 1]} ${formatPrice(value)}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: barsHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                key: Key('bar-$index'),
                height: height,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _letters[day.weekday - 1],
            style: TextStyle(
              color: isToday ? AppTheme.brandOrange : AppTheme.textMuted,
              fontSize: 12,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}