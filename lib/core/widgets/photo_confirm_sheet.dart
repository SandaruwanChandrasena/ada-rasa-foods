import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../features/menu/domain/photo_picker.dart';
import 'food_image.dart';

// Shows the picked photo big, so the owner can check it first.
// Closing the sheet any other way counts as Cancel.
Future<PhotoChoice> showPhotoConfirmSheet(
  BuildContext context,
  String path,
) async {
  final choice = await showModalBottomSheet<PhotoChoice>(
    context: context,
    // Lets the sheet be taller than half the screen.
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => PhotoConfirmSheet(path: path),
  );
  return choice ?? PhotoChoice.cancel;
}

// The "Use this photo?" sheet. Public, so tests can find it.
class PhotoConfirmSheet extends StatelessWidget {
  const PhotoConfirmSheet({super.key, required this.path});

  static const double photoHeight = 240;

  final String path;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      // Scrolls on small phones, so the buttons are never cut off.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Use this photo?',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(path),
                key: const Key('confirm-photo'),
                height: photoHeight,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const FoodImage(
                  imageUrl: '',
                  height: photoHeight,
                  iconSize: 48,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Customers will see this photo.',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(PhotoChoice.use),
              child: const Text('Use photo'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pop(PhotoChoice.pickAnother),
              child: const Text('Pick another'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(PhotoChoice.cancel),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}