import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../domain/dish.dart';
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
          Navigator.of(context).maybePop();
        }
      },
      builder: (context, state) {
        final errors = state.showErrors;

        return Scaffold(
          appBar: AppBar(
            title: Text(state.isEditing ? 'Edit dish' : 'Add dish'),
            actions: [
              if (state.isEditing)
                IconButton(
                  tooltip: 'Delete dish',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: state.isBusy ? null : () => _delete(context),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              TextField(
                controller: _name,
                enabled: !state.isBusy,
                maxLength: DishFormState.maxName,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Dish name',
                  hintText: 'Chicken Kottu',
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
                  errorText: errors ? state.categoryError : null,
                ),
                onChanged: cubit.categoryChanged,
              ),
              if (widget.categories.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final category in widget.categories)
                      ActionChip(
                        label: Text(category),
                        onPressed: state.isBusy
                            ? null
                            : () {
                                _category.text = category;
                                cubit.categoryChanged(category);
                              },
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available'),
                subtitle: const Text('Customers can order this dish.'),
                value: state.available,
                onChanged: state.isBusy ? null : cubit.availableChanged,
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed: state.isBusy ? null : cubit.save,
                child: state.status == DishFormStatus.saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(state.isEditing ? 'Save changes' : 'Add dish'),
              ),
            ),
          ),
        );
      },
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
              backgroundColor: Colors.red.shade700,
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