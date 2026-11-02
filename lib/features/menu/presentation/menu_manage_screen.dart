import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/dish.dart';
import 'dish_row.dart';
import 'menu_manage_cubit.dart';
import 'menu_manage_state.dart';

// The owner's Menu tab (RES-3). Add and edit pages open by callbacks.
class MenuManageView extends StatelessWidget {
  const MenuManageView({
    super.key,
    required this.onAdd,
    required this.onEdit,
  });

  final VoidCallback onAdd;
  final void Function(Dish dish) onEdit;

  @override
  Widget build(BuildContext context) {
    return BlocListener<MenuManageCubit, MenuManageState>(
      listenWhen: (previous, current) =>
          previous.noticeId != current.noticeId,
      listener: (context, state) {
        final notice = state.notice;
        if (notice == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(notice)));
      },
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add dish'),
        ),
        body: BlocBuilder<MenuManageCubit, MenuManageState>(
          builder: (context, state) {
            switch (state.view) {
              case MenuView.loading:
                return const Center(child: CircularProgressIndicator());
              case MenuView.failure:
                return _Message(
                  text: state.errorMessage ?? 'Something went wrong.',
                  buttonText: 'Retry',
                  onPressed: () => context.read<MenuManageCubit>().retry(),
                );
              case MenuView.loaded:
                if (state.dishes.isEmpty) {
                  return _Message(
                    text: 'No dishes yet.',
                    buttonText: 'Add your first dish',
                    onPressed: onAdd,
                  );
                }
                return _MenuList(state: state, onEdit: onEdit);
            }
          },
        ),
      ),
    );
  }
}

class _MenuList extends StatelessWidget {
  const _MenuList({required this.state, required this.onEdit});

  final MenuManageState state;
  final void Function(Dish dish) onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      // Room at the bottom, so the Add button never hides the last dish.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        for (final category in state.categories) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              category,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final dish in state.dishesIn(category))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                key: ValueKey('dish-${dish.id}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => onEdit(dish),
                child: DishRow(
                  dish: dish,
                  trailing: _AvailableSwitch(
                    dish: dish,
                    busy: state.isBusy(dish),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// "Available" switch. A small spinner while it saves.
class _AvailableSwitch extends StatelessWidget {
  const _AvailableSwitch({required this.dish, required this.busy});

  final Dish dish;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 48,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Switch(
      value: dish.available,
      onChanged: (value) => context
          .read<MenuManageCubit>()
          .setAvailable(dish, available: value),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.buttonText,
    required this.onPressed,
  });

  final String text;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }
}