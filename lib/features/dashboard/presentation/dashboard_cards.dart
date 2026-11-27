import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/food_image.dart';
import '../../../core/widgets/section_card.dart';
import '../domain/day_summary.dart';

enum StatTone { green, orange }

// One number on the dashboard, like Sales or New.
// With [onTap] it shows a ">" and opens the Orders tab.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.tone = StatTone.orange,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final StatTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final green = tone == StatTone.green;
    final color = green ? AppTheme.successGreen : AppTheme.brandOrange;
    final background = green ? AppTheme.successBg : AppTheme.softOrange;
    final tap = onTap;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(icon, color: color, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                  if (tap != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textMuted,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // A big font shrinks the number, so it always shows in full.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The soft red row: rejected or cancelled today.
class DroppedRow extends StatelessWidget {
  const DroppedRow({super.key, required this.count});

  static const label = 'Rejected or cancelled';

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.dangerBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: AppTheme.dangerRed),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.dangerRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(
                color: AppTheme.dangerRed,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// "Top dishes today": photo, name and how many were sold.
class TopDishesCard extends StatelessWidget {
  const TopDishesCard({super.key, required this.dishes});

  static const title = 'Top dishes today';
  static const emptyText = 'No orders yet today';

  final List<TopDish> dishes;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.local_fire_department_rounded,
      title: title,
      child: dishes.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                emptyText,
                style: TextStyle(color: AppTheme.textMuted),
              ),
            )
          : Column(
              children: [
                for (final dish in dishes) _TopDishRow(dish: dish),
              ],
            ),
    );
  }
}

class _TopDishRow extends StatelessWidget {
  const _TopDishRow({required this.dish});

  final TopDish dish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          FoodImage(
            imageUrl: dish.imageUrl,
            width: 44,
            height: 44,
            borderRadius: 10,
            iconSize: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              dish.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.softOrange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              child: Text(
                '× ${dish.quantity}',
                style: const TextStyle(
                  color: AppTheme.deepOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}