import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';
import '../../../core/widgets/food_image.dart';
import '../domain/dish.dart';

// One dish on the restaurant page.
class DishRow extends StatelessWidget {
  const DishRow({
    super.key,
    required this.dish,
    this.trailing,
    this.onTap,
  });

  final Dish dish;

  // Shown next to the price, like the Add button from the cart feature.
  final Widget? trailing;

  // When given, the row becomes a card with a soft border that opens the
  // dish page (CUS-14). Taps on [trailing] still go to [trailing].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FoodImage(imageUrl: dish.imageUrl, width: 84, height: 84, iconSize: 32),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dish.name,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (dish.description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  dish.description,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatPrice(dish.price),
                      style: textTheme.titleSmall?.copyWith(
                        color: AppTheme.brandOrange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ],
          ),
        ),
      ],
    );

    // Not available: faded, with a label on top.
    final body = dish.available
        ? content
        : Stack(
            children: [
              Opacity(opacity: 0.4, child: content),
              const Positioned(top: 0, right: 0, child: _NotAvailableLabel()),
            ],
          );

    final tap = onTap;
    if (tap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: body,
      );
    }

    // A border, not a shadow, so long menus scroll smoothly.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tap,
          child: Padding(padding: const EdgeInsets.all(10), child: body),
        ),
      ),
    );
  }
}

class _NotAvailableLabel extends StatelessWidget {
  const _NotAvailableLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade700,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Not available',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}