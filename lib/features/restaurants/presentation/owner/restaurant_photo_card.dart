import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/food_image.dart';
import '../../../../core/widgets/photo_confirm_sheet.dart';
import '../../../auth/domain/phone_checks.dart';
import '../../../menu/domain/photo_picker.dart';
import '../../domain/restaurant.dart';
import 'edit_shop_screen.dart';
import 'my_restaurant_cubit.dart';
import 'restaurant_photo_cubit.dart';

// Opens the Edit shop page.
void openEditShop(BuildContext context, Restaurant restaurant) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EditShopScreen(restaurant: restaurant),
    ),
  );
}

// The big restaurant cover photo on the owner's Profile tab (RES-3),
// with its buttons under it, then the shop details and an Edit pill.
// The live photo comes from MyRestaurantCubit.
class RestaurantPhotoCard extends StatelessWidget {
  const RestaurantPhotoCard({super.key, this.onEditShop = openEditShop});

  static const double coverHeight = 180;

  // Tests give a fake, so no real page opens.
  final void Function(BuildContext context, Restaurant restaurant)
      onEditShop;

  @override
  Widget build(BuildContext context) {
    final restaurant =
        context.select((MyRestaurantCubit cubit) => cubit.state.restaurant);

    // Wait for the restaurant, so we never show a wrong photo.
    if (restaurant == null) return const SizedBox.shrink();

    return BlocConsumer<RestaurantPhotoCubit, RestaurantPhotoState>(
      listenWhen: (previous, current) =>
          previous.noticeId != current.noticeId,
      listener: (context, state) {
        final notice = state.notice;
        if (notice == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(notice)));
      },
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cover(context, state, restaurant),
              if (restaurant.hasImage) ...[
                const SizedBox(height: 10),
                // On white, so they show on any photo. Wrap for big fonts.
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      key: const Key('remove-photo-button'),
                      icon: Icons.delete_rounded,
                      text: 'Remove',
                      color: AppTheme.dangerRed,
                      background: AppTheme.dangerBg,
                      onTap: state.isBusy
                          ? null
                          : () => _confirmRemove(context),
                    ),
                    _Pill(
                      key: const Key('change-photo-button'),
                      icon: Icons.photo_camera_rounded,
                      text: 'Change photo',
                      color: AppTheme.deepOrange,
                      background: AppTheme.softOrange,
                      onTap: state.isBusy ? null : () => _pick(context),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textDark,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${restaurant.cuisine} · ${restaurant.address}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Pill(
                    key: const Key('edit-shop-button'),
                    icon: Icons.edit_rounded,
                    text: 'Edit',
                    color: AppTheme.deepOrange,
                    background: AppTheme.softOrange,
                    onTap: () => onEditShop(context, restaurant),
                  ),
                ],
              ),
              if (restaurant.hasPhone) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_rounded,
                      size: 18,
                      color: AppTheme.brandOrange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      PhoneChecks.format(restaurant.phone),
                      style: const TextStyle(color: AppTheme.textDark),
                    ),
                  ],
                ),
              ],
              if (restaurant.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  restaurant.description,
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _cover(
    BuildContext context,
    RestaurantPhotoState state,
    Restaurant restaurant,
  ) {
    final hasPhoto = restaurant.hasImage;
    final path = state.photoPath;

    final Widget picture;
    if (path != null) {
      picture = Image.file(
        File(path),
        key: const Key('restaurant-picked-photo'),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const _AddPhotoBox(),
      );
    } else if (hasPhoto) {
      picture = FoodImage(
        imageUrl: restaurant.imageUrl,
        width: double.infinity,
        height: coverHeight,
        borderRadius: 0,
      );
    } else {
      picture = const _AddPhotoBox();
    }

    return SizedBox(
      height: coverHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            button: true,
            label: hasPhoto ? 'Change photo' : 'Add a photo',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('restaurant-photo-box'),
                onTap: state.isBusy ? null : () => _pick(context),
                child: picture,
              ),
            ),
          ),
          if (state.isUploading)
            _DarkLayer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Uploading ${(state.uploadProgress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 160,
                    child: LinearProgressIndicator(
                      value: state.uploadProgress,
                      minHeight: 4,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            )
          else if (state.isBusy)
            const _DarkLayer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Saving...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // The owner sees the photo big and taps Use photo before it uploads.
  Future<void> _pick(BuildContext context) {
    return context.read<RestaurantPhotoCubit>().pickAndUpload(
      confirm: (path) async {
        if (!context.mounted) return PhotoChoice.cancel;
        return showPhotoConfirmSheet(context, path);
      },
    );
  }

  // It saves at once, with no Save step to undo, so we ask first.
  Future<void> _confirmRemove(BuildContext context) async {
    final cubit = context.read<RestaurantPhotoCubit>();

    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove the restaurant photo?'),
        content: const Text('Customers will see the default picture.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            // The app theme makes FilledButton full width, so we set a size.
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 40),
              backgroundColor: AppTheme.dangerRed,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes ?? false) await cubit.removePhoto();
  }
}

// Soft orange box with a camera, when there is no photo yet.
class _AddPhotoBox extends StatelessWidget {
  const _AddPhotoBox();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppTheme.softOrange,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_rounded,
            size: 36,
            color: AppTheme.brandOrange,
          ),
          SizedBox(height: 6),
          Text(
            'Add a photo',
            style: TextStyle(
              color: AppTheme.deepOrange,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// A dark layer over the photo while it uploads or saves.
class _DarkLayer extends StatelessWidget {
  const _DarkLayer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(child: child),
      ),
    );
  }
}

// A soft pill button with an icon and a word, like "Edit".
class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  // Null while the photo saves. The pill stays, so nothing jumps.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}