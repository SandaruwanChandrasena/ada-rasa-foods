import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';
import '../../../core/widgets/food_image.dart';
import '../../../core/widgets/section_card.dart';
import '../domain/dash_period.dart';
import '../domain/day_summary.dart';

// The orange card: shop name, sales, done and the period switch.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.shopName,
    required this.summary,
    required this.period,
    required this.onPick,
    this.onDone,
  });

  final String shopName;
  final DaySummary summary;
  final DashPeriod period;
  final ValueChanged<DashPeriod> onPick;

  // Opens the Done chip. Null: Done can't be tapped.
  final VoidCallback? onDone;

  static const Color _faintWhite = Color(0xE6FFFFFF);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.brandOrange,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (shopName.isNotEmpty)
              Text(
                shopName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _faintWhite, fontSize: 13),
              ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _sales()),
                const SizedBox(width: 12),
                _DoneBlock(count: summary.doneCount, onTap: onDone),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in DashPeriod.values)
                  _PeriodChip(
                    period: p,
                    selected: p == period,
                    onTap: () => onPick(p),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sales() {
    return Column(
      key: const Key('hero-sales'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A big font shrinks the amount, so it always shows in full.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatPrice(summary.sales),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Text(
          'sales',
          style: TextStyle(color: _faintWhite, fontSize: 12),
        ),
      ],
    );
  }
}

class _DoneBlock extends StatelessWidget {
  const _DoneBlock({required this.count, required this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;

    return Material(
      key: const Key('stat-done'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'done',
                    style: TextStyle(
                      color: HeroCard._faintWhite,
                      fontSize: 12,
                    ),
                  ),
                  if (tap != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: HeroCard._faintWhite,
                      size: 16,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.period,
    required this.selected,
    required this.onTap,
  });

  static const Color _glass = Color(0x38FFFFFF);

  final DashPeriod period;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        key: Key('period-${period.name}'),
        color: selected ? Colors.white : _glass,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              period.label,
              style: TextStyle(
                color: selected ? AppTheme.deepOrange : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// One row of three small pills: New, Active and Rejected.
class StatusPills extends StatelessWidget {
  const StatusPills({
    super.key,
    required this.summary,
    this.onNew,
    this.onActive,
  });

  final DaySummary summary;
  final VoidCallback? onNew;
  final VoidCallback? onActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Pill(
            key: const Key('stat-new'),
            icon: Icons.notifications_active_rounded,
            label: 'New',
            count: summary.newCount,
            onTap: onNew,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Pill(
            key: const Key('stat-active'),
            icon: Icons.soup_kitchen_rounded,
            label: 'Active',
            count: summary.activeCount,
            onTap: onActive,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Pill(
            key: const Key('stat-dropped'),
            icon: Icons.cancel_rounded,
            label: 'Rejected',
            semanticLabel: 'Rejected or cancelled',
            count: summary.droppedCount,
            danger: true,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    this.semanticLabel,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? semanticLabel;
  final int count;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppTheme.dangerRed : AppTheme.deepOrange;

    return Semantics(
      container: true,
      label: '${semanticLabel ?? label} $count',
      button: onTap != null,
      excludeSemantics: true,
      child: Material(
        color: danger ? AppTheme.dangerBg : AppTheme.softOrange,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: color,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// "Top dishes": rank, photo, name, how many, and a share bar.
class TopDishesCard extends StatelessWidget {
  const TopDishesCard({
    super.key,
    required this.dishes,
    required this.period,
  });

  static const title = 'Top dishes';

  final List<TopDish> dishes;
  final DashPeriod period;

  static String emptyTextFor(DashPeriod period) {
    return period == DashPeriod.today
        ? 'No orders yet today'
        : 'No orders in the last ${period.label}';
  }

  @override
  Widget build(BuildContext context) {
    final most = dishes.isEmpty ? 1 : dishes.first.quantity;

    return SectionCard(
      icon: Icons.local_fire_department_rounded,
      title: title,
      child: dishes.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                emptyTextFor(period),
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < dishes.length; i++)
                  _TopDishRow(rank: i + 1, dish: dishes[i], most: most),
              ],
            ),
    );
  }
}

class _TopDishRow extends StatelessWidget {
  const _TopDishRow({
    required this.rank,
    required this.dish,
    required this.most,
  });

  final int rank;
  final TopDish dish;

  // The top dish's quantity. Its bar is full.
  final int most;

  @override
  Widget build(BuildContext context) {
    final share =
        most <= 0 ? 0.0 : (dish.quantity / most).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              style: const TextStyle(
                color: AppTheme.brandOrange,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FoodImage(
            imageUrl: dish.imageUrl,
            width: 40,
            height: 40,
            borderRadius: 10,
            iconSize: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dish.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '× ${dish.quantity}',
                      style: const TextStyle(
                        color: AppTheme.deepOrange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: ColoredBox(
                      color: AppTheme.softOrange,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          key: Key('share-${dish.dishId}'),
                          widthFactor: share,
                          heightFactor: 1,
                          child: const ColoredBox(
                            color: AppTheme.brandOrange,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}