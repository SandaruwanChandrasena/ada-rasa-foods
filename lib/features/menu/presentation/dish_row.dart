import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';
import '../../../core/widgets/food_image.dart';
import '../domain/dish.dart';

// One dish on the restaurant page. No Add button yet (comes with the cart).
class DishRow extends StatelessWidget {
  const DishRow({super.key, required this.dish});

  final Dish dish;

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
              Text(
                formatPrice(dish.price),
                style: textTheme.titleSmall?.copyWith(
                  color: AppTheme.brandOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (dish.available) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: content,
      );
    }

    // Not available: faded, with a label on top.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        children: [
          Opacity(opacity: 0.4, child: content),
          const Positioned(top: 0, right: 0, child: _NotAvailableLabel()),
        ],
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