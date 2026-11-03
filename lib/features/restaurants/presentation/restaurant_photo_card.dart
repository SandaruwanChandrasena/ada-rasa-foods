import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/food_image.dart';
import '../../../core/widgets/photo_confirm_sheet.dart';
import '../../menu/domain/photo_picker.dart';
import 'my_restaurant_cubit.dart';
import 'restaurant_photo_cubit.dart';

// The restaurant photo at the top of the owner's Menu tab (RES-3).
// The live photo comes from MyRestaurantCubit.
class RestaurantPhotoCard extends StatelessWidget {
  const RestaurantPhotoCard({super.key});

  static const double photoWidth = 96;
  static const double photoHeight = 64;

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
        final hasPhoto = restaurant.hasImage;
        final textTheme = Theme.of(context).textTheme;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Thumbnail(
                        imageUrl: restaurant.imageUrl,
                        photoPath: state.photoPath,
                        onTap: state.isBusy ? null : () => _pick(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Restaurant photo',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Customers see it on your restaurant page.',
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _actions(context, state, hasPhoto),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (state.isUploading) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: state.uploadProgress),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _actions(
    BuildContext context,
    RestaurantPhotoState state,
    bool hasPhoto,
  ) {
    if (state.isUploading) {
      final percent = (state.uploadProgress * 100).round();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Uploading $percent%'),
      );
    }
    if (state.isBusy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Expanded(child: Text('Saving...')),
          ],
        ),
      );
    }

    // Wrap, not Row, so long button text never overflows.
    return Wrap(
      spacing: 4,
      children: [
        TextButton(
          onPressed: () => _pick(context),
          child: Text(hasPhoto ? 'Change photo' : 'Choose photo'),
        ),
        if (hasPhoto)
          TextButton(
            onPressed: () => _confirmRemove(context),
            child: const Text('Remove photo'),
          ),
      ],
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
              backgroundColor: Colors.red.shade700,
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

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.imageUrl,
    required this.photoPath,
    required this.onTap,
  });

  final String imageUrl;

  // The picked photo while it uploads.
  final String? photoPath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const width = RestaurantPhotoCard.photoWidth;
    const height = RestaurantPhotoCard.photoHeight;
    final path = photoPath;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('restaurant-photo-box'),
        onTap: onTap,
        child: path == null
            ? FoodImage(
                imageUrl: imageUrl,
                width: width,
                height: height,
                borderRadius: 8,
                iconSize: 28,
              )
            : Image.file(
                File(path),
                key: const Key('restaurant-picked-photo'),
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const FoodImage(
                  imageUrl: '',
                  width: width,
                  height: height,
                  borderRadius: 8,
                  iconSize: 28,
                ),
              ),
      ),
    );
  }
}