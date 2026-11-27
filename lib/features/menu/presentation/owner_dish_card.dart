import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';
import '../../../core/widgets/food_image.dart';
import '../domain/dish.dart';

// One dish on the owner's Menu tab: photo, name, price, a pencil,
// and the Available switch (RES-3). Tapping the card also edits it.
class OwnerDishCard extends StatelessWidget {
  const OwnerDishCard({
    super.key,
    required this.dish,
    required this.busy,
    required this.onEdit,
    required this.onAvailable,
  });

  static const double photoSize = 64;

  final Dish dish;

  // True while the switch saves. Shows a spinner, not the switch.
  final bool busy;

  final VoidCallback onEdit;
  final ValueChanged<bool> onAvailable;

  @override
  Widget build(BuildContext context) {
    final available = dish.available;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('dish-${dish.id}'),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Photo(dish: dish),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dish.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: available
                                ? AppTheme.textDark
                                : AppTheme.textMuted,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatPrice(dish.price),
                          style: TextStyle(
                            color: available
                                ? AppTheme.brandOrange
                                : AppTheme.textMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _EditButton(dishId: dish.id, onTap: onEdit),
                ],
              ),
              const Divider(height: 20, thickness: 1, color: AppTheme.border),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      available ? 'Available' : 'Not available',
                      style: TextStyle(
                        color: available
                            ? AppTheme.successGreen
                            : AppTheme.dangerRed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (busy)
                    const SizedBox(
                      width: 52,
                      height: 48,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    Switch(value: available, onChanged: onAvailable),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The dish photo. A white layer fades it when not available.
class _Photo extends StatelessWidget {
  const _Photo({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    const size = OwnerDishCard.photoSize;

    // A layer, not Opacity, so long menus scroll smoothly.
    return Stack(
      children: [
        FoodImage(
          imageUrl: dish.imageUrl,
          width: size,
          height: size,
          borderRadius: 12,
          iconSize: 26,
        ),
        if (!dish.available)
          Positioned.fill(
            child: DecoratedBox(
              key: const Key('not-available-fade'),
              decoration: BoxDecoration(
                color: const Color(0x99FFFFFF),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }
}

// A round soft orange pencil that opens the Edit page.
class _EditButton extends StatelessWidget {
  const _EditButton({required this.dishId, required this.onTap});

  final String dishId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Edit',
      excludeSemantics: true,
      child: Material(
        key: ValueKey('edit-$dishId'),
        color: AppTheme.softOrange,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.edit_rounded,
              size: 20,
              color: AppTheme.brandOrange,
            ),
          ),
        ),
      ),
    );
  }
}