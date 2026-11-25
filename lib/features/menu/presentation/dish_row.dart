import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';
import '../../../core/widgets/food_image.dart';
import '../domain/dish.dart';
import 'dish_photo_hero.dart';

// One dish on the restaurant page.
class DishRow extends StatelessWidget {
  const DishRow({
    super.key,
    required this.dish,
    this.trailing,
    this.onTap,
  });

  static const double photoSize = 88;

  // Makes the photo of a dish that is not available look faded.
  static const Color notAvailableFade = Color(0x99FFFFFF);

  final Dish dish;

  // Shown next to the price, like the Add button from the cart feature.
  final Widget? trailing;

  // When given, the row becomes a card with a soft border that opens the
  // dish page (CUS-14). Taps on [trailing] still go to [trailing].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final available = dish.available;

    // A layer, not Opacity, so long menus scroll smoothly.
    final photo = Stack(
      children: [
        FoodImage(
          imageUrl: dish.imageUrl,
          width: photoSize,
          height: photoSize,
          borderRadius: 14,
          iconSize: 32,
        ),
        if (!available)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: notAvailableFade,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
      ],
    );

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Only tappable rows open the dish page, so only they fly.
        if (onTap != null)
          DishPhotoHero(dishId: dish.id, child: photo)
        else
          photo,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!available) ...[
                const _NotAvailableLabel(),
                const SizedBox(height: 4),
              ],
              Text(
                dish.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: available ? AppTheme.textDark : AppTheme.textMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (dish.description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  dish.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatPrice(dish.price),
                      style: TextStyle(
                        color: available
                            ? AppTheme.brandOrange
                            : AppTheme.textMuted,
                        fontSize: 15,
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

    final tap = onTap;
    if (tap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: content,
      );
    }

    // A border, not a shadow, so long menus scroll smoothly.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tap,
          child: Padding(padding: const EdgeInsets.all(12), child: content),
        ),
      ),
    );
  }
}

// "Not available" in soft red, like the labels on the dish page.
class _NotAvailableLabel extends StatelessWidget {
  const _NotAvailableLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        color: AppTheme.dangerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel_rounded, size: 14, color: AppTheme.dangerRed),
          SizedBox(width: 3),
          Text(
            'Not available',
            style: TextStyle(
              color: AppTheme.dangerRed,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}