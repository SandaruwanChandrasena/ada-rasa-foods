import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/food_image.dart';
import '../../../core/widgets/open_status_chip.dart';
import '../domain/restaurant.dart';

// One restaurant in the customer home list.
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  static const double photoHeight = 150;

  // A see-through white layer that makes a closed place's photo look faded.
  static const Color closedFade = Color(0x73FFFFFF);

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final open = restaurant.canTakeOrders;
    final nameColor = open ? AppTheme.textDark : AppTheme.textMuted;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                FoodImage(
                  imageUrl: restaurant.imageUrl,
                  width: double.infinity,
                  height: photoHeight,
                  borderRadius: 0,
                  iconSize: 48,
                ),
                // A layer, not Opacity, so long lists stay smooth.
                if (!open)
                  const Positioned.fill(
                    child: ColoredBox(color: closedFade),
                  ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: OpenStatusChip(isOpen: open),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: nameColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.restaurant_menu_rounded,
                        size: 16,
                        color: AppTheme.brandOrange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          restaurant.cuisine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: AppTheme.brandOrange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          restaurant.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}