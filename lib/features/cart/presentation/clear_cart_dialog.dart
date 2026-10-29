import 'package:material_ui/material_ui.dart';

// Asks before mixing food from two restaurants (CUS-13). True means Yes.
Future<bool> showClearCartDialog(
  BuildContext context, {
  required String currentRestaurant,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Clear cart and add this item?'),
      content: Text(
        'Your cart has food from $currentRestaurant. '
        'A cart can hold food from one restaurant only.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // The app theme makes FilledButton full width, so we set a size here.
          style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );
  return answer ?? false;
}