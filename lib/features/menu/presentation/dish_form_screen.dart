import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/food_image.dart';
import '../../../core/widgets/photo_confirm_sheet.dart';
import '../../../core/widgets/section_card.dart';
import '../domain/dish.dart';
import '../domain/photo_picker.dart';
import 'dish_form_cubit.dart';
import 'dish_form_state.dart';

// What the Menu tab sends to the dish page.
class DishFormArgs {
  const DishFormArgs({
    required this.restaurantId,
    this.categories = const [],
    this.dish,
  });

  final String restaurantId;

  // Categories already on the menu, shown as chips.
  final List<String> categories;

  // Null when adding a new dish.
  final Dish? dish;
}

// The Add dish and Edit dish page (RES-3).
class DishFormScreen extends StatelessWidget {
  const DishFormScreen({super.key, required this.args});

  final DishFormArgs args;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DishFormCubit>(
      create: (_) => DishFormCubit(
        sl(),
        uploader: sl(),
        picker: sl(),
        restaurantId: args.restaurantId,
        dish: args.dish,
      ),
      child: DishFormView(categories: args.categories),
    );
  }
}

// The page itself. Public, so tests can give it a cubit.
class DishFormView extends StatefulWidget {
  const DishFormView({super.key, this.categories = const []});

  final List<String> categories;

  @override
  State<DishFormView> createState() => _DishFormViewState();
}

class _DishFormViewState extends State<DishFormView> {
  late final DishFormState _start = context.read<DishFormCubit>().state;
  late final _name = TextEditingController(text: _start.name);
  late final _description = TextEditingController(text: _start.description);
  late final _price = TextEditingController(text: _start.price);
  late final _category = TextEditingController(text: _start.category);

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DishFormCubit>();

    return BlocConsumer<DishFormCubit, DishFormState>(
      listenWhen: (previous, current) =>
          previous.noticeId != current.noticeId,
      listener: (context, state) {
        final notice = state.notice;
        if (notice != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(notice)));
        }
        if (state.status == DishFormStatus.saved ||
            state.status == DishFormStatus.deleted) {
          // PopScope still blocks in this frame, so we pop directly.
          final navigator = Navigator.of(context);
          if (navigator.canPop()) navigator.pop();
        }
      },
      builder: (context, state) {
        final errors = state.showErrors;

        return PopScope(
          // Leaving halfway would upload a photo that is never saved.
          canPop: !state.isBusy,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _showWait(context);
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(state.isEditing ? 'Edit dish' : 'Add dish'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                DishPhotoBox(
                  state: state,
                  onPick: _pickPhoto,
                  onRemove: cubit.removePhoto,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  enabled: !state.isBusy,
                  maxLength: DishFormState.maxName,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Dish name',
                    hintText: 'Chicken Kottu',
                    prefixIcon: const _FieldIcon(Icons.restaurant_rounded),
                    errorText: errors ? state.nameError : null,
                  ),
                  onChanged: cubit.nameChanged,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _description,
                  enabled: !state.isBusy,
                  maxLength: DishFormState.maxDescription,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: const _FieldIcon(Icons.notes_rounded),
                    errorText: errors ? state.descriptionError : null,
                  ),
                  onChanged: cubit.descriptionChanged,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _price,
                  enabled: !state.isBusy,
                  keyboardType: TextInputType.number,
                  // Whole rupees only, so no dots or letters.
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Price',
                    prefixText: 'Rs. ',
                    prefixIcon: const _FieldIcon(Icons.sell_rounded),
                    errorText: errors ? state.priceError : null,
                  ),
                  onChanged: cubit.priceChanged,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _category,
                  enabled: !state.isBusy,
                  maxLength: DishFormState.maxCategory,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    hintText: 'Kottu',
                    prefixIcon: const _FieldIcon(Icons.category_rounded),
                    errorText: errors ? state.categoryError : null,
                  ),
                  onChanged: cubit.categoryChanged,
                ),
                if (widget.categories.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in widget.categories)
                        CategoryChip(
                          label: category,
                          // Orange when it matches the box.
                          selected: state.category.trim() == category,
                          onTap: state.isBusy
                              ? null
                              : () {
                                  _category.text = category;
                                  cubit.categoryChanged(category);
                                },
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                _AvailableCard(
                  available: state.available,
                  onChanged: state.isBusy ? null : cubit.availableChanged,
                ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.isUploading) ...[
                      LinearProgressIndicator(value: state.uploadProgress),
                      const SizedBox(height: 8),
                    ],
                    if (state.isEditing)
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              key: const Key('delete-dish-button'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.dangerRed,
                                backgroundColor: AppTheme.dangerBg,
                                minimumSize: const Size(0, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: state.isBusy
                                  ? null
                                  : () => _delete(context),
                              child: const _IconText(
                                icon: Icons.delete_rounded,
                                text: 'Delete',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: _saveButton(state, cubit)),
                        ],
                      )
                    else
                      _saveButton(state, cubit),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // The owner sees the photo big and taps Use photo first.
  Future<void> _pickPhoto() {
    return context.read<DishFormCubit>().pickPhoto(
      confirm: (path) async {
        if (!mounted) return PhotoChoice.cancel;
        return showPhotoConfirmSheet(context, path);
      },
    );
  }

  Widget _saveButton(DishFormState state, DishFormCubit cubit) {
    return FilledButton(
      // The app theme makes FilledButton full width, so we set a size.
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onPressed: state.isBusy ? null : cubit.save,
      child: _buttonChild(state),
    );
  }

  Widget _buttonChild(DishFormState state) {
    if (state.isUploading) {
      return Text('Uploading ${(state.uploadProgress * 100).round()}%');
    }
    if (state.status == DishFormStatus.saving) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    return state.isEditing
        ? const _IconText(icon: Icons.check_rounded, text: 'Save')
        : const _IconText(icon: Icons.add_rounded, text: 'Add dish');
  }

  void _showWait(BuildContext context) {
    final deleting =
        context.read<DishFormCubit>().state.status == DishFormStatus.deleting;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            deleting
                ? 'Please wait, deleting the dish.'
                : 'Please wait, saving the dish.',
          ),
        ),
      );
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<DishFormCubit>();
    final name = cubit.state.original?.name ?? 'this dish';

    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $name?'),
        content: const Text(
          'Customers will not see it any more. Old orders stay the same. '
          'You cannot undo this.',
        ),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes ?? false) await cubit.delete();
  }
}

// The dish photo, like the Profile cover: a camera and a bin on it,
// or "Add a photo" when empty. Public, so tests can find it.
class DishPhotoBox extends StatelessWidget {
  const DishPhotoBox({
    super.key,
    required this.state,
    required this.onPick,
    required this.onRemove,
  });

  static const double height = 180;

  final DishFormState state;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final busy = state.isBusy;
    final path = state.photoPath;

    final Widget picture;
    if (path != null) {
      picture = Image.file(
        File(path),
        key: const Key('picked-photo'),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const _AddPhotoBox(),
      );
    } else if (state.photoUrl.isNotEmpty) {
      picture = FoodImage(
        imageUrl: state.photoUrl,
        width: double.infinity,
        height: height,
        borderRadius: 0,
        iconSize: 48,
      );
    } else {
      picture = const _AddPhotoBox();
    }

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            button: true,
            label: state.hasPhoto ? 'Change photo' : 'Add a photo',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('dish-photo-box'),
                onTap: busy ? null : onPick,
                child: picture,
              ),
            ),
          ),
          // Hidden while saving, so the photo can't change halfway.
          if (state.hasPhoto && !busy)
            Positioned(
              right: 10,
              bottom: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CircleButton(
                    key: const Key('dish-remove-photo'),
                    icon: Icons.delete_rounded,
                    color: AppTheme.dangerRed,
                    label: 'Remove photo',
                    onTap: onRemove,
                  ),
                  const SizedBox(width: 8),
                  _CircleButton(
                    key: const Key('dish-change-photo'),
                    icon: Icons.photo_camera_rounded,
                    color: AppTheme.brandOrange,
                    label: 'Change photo',
                    onTap: onPick,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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

// A white round button on the photo.
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}

// An orange rounded icon at the start of a text box.
class _FieldIcon extends StatelessWidget {
  const _FieldIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: AppTheme.brandOrange);
  }
}

// A category chip: orange when it matches the box, else grey.
// Public, so tests can find it.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color grey = Color(0xFFF2F2F2);

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? AppTheme.brandOrange : grey,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// "Available" in a white card, like the Open card on Profile.
class _AvailableCard extends StatelessWidget {
  const _AvailableCard({required this.available, required this.onChanged});

  final bool available;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            const SectionIcon(icon: Icons.check_circle_rounded),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available',
                    style: TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    available
                        ? 'Customers can order it.'
                        : 'Customers cannot order it.',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: available, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

// An icon and a word that shrinks with "..." on big fonts.
class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

// Shown only if the dish page opens without its data (after a restart).
class DishFormMissing extends StatelessWidget {
  const DishFormMissing({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dish')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Please open this page from the Menu tab.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}