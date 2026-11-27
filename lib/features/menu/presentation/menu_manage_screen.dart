import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/dish.dart';
import 'menu_manage_cubit.dart';
import 'menu_manage_state.dart';
import 'owner_dish_card.dart';

// The owner's Menu tab (RES-3). Add and edit pages open by callbacks.
class MenuManageView extends StatefulWidget {
  const MenuManageView({
    super.key,
    required this.onAdd,
    required this.onEdit,
  });

  final VoidCallback onAdd;
  final void Function(Dish dish) onEdit;

  @override
  State<MenuManageView> createState() => _MenuManageViewState();
}

class _MenuManageViewState extends State<MenuManageView> {
  // The picked category chip. Null means "All".
  String? _picked;

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
        appBar: AppBar(
          title: const Text('Menu'),
          centerTitle: false,
          actions: [
            _AddPill(onTap: widget.onAdd),
            const SizedBox(width: 16),
          ],
        ),
        body: BlocBuilder<MenuManageCubit, MenuManageState>(
          builder: (context, state) {
            switch (state.view) {
              case MenuView.loading:
                return const Center(child: CircularProgressIndicator());
              case MenuView.failure:
                return _Message(
                  icon: Icons.wifi_off_rounded,
                  title: state.errorMessage ?? 'Something went wrong.',
                  buttonText: 'Retry',
                  onPressed: () => context.read<MenuManageCubit>().retry(),
                );
              case MenuView.loaded:
                if (state.dishes.isEmpty) {
                  return _Message(
                    icon: Icons.restaurant_menu_rounded,
                    title: 'No dishes yet',
                    subtitle: 'Add your first dish to the menu.',
                    buttonText: 'Add your first dish',
                    onPressed: widget.onAdd,
                  );
                }
                return _menu(context, state);
            }
          },
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, MenuManageState state) {
    final categories = state.categories;
    // A chip whose last dish is gone falls back to "All".
    final picked = categories.contains(_picked) ? _picked : null;

    Widget card(Dish dish) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OwnerDishCard(
          dish: dish,
          busy: state.isBusy(dish),
          onEdit: () => widget.onEdit(dish),
          onAvailable: (value) => context
              .read<MenuManageCubit>()
              .setAvailable(dish, available: value),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            children: [
              _Chip(
                label: 'All ${state.dishes.length}',
                selected: picked == null,
                onTap: () => setState(() => _picked = null),
              ),
              for (final category in categories) ...[
                const SizedBox(width: 8),
                _Chip(
                  label: '$category ${state.dishesIn(category).length}',
                  selected: picked == category,
                  onTap: () => setState(() => _picked = category),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (picked != null)
                for (final dish in state.dishesIn(picked)) card(dish)
              else
                for (final category in categories) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  for (final dish in state.dishesIn(category)) card(dish),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

// The orange "+ Add dish" pill in the top bar.
class _AddPill extends StatelessWidget {
  const _AddPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('add-dish-pill'),
      color: AppTheme.brandOrange,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(10, 7, 14, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 20, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'Add dish',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A category chip, like the board chips: orange when picked.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color grey = Color(0xFFF2F2F2);

  final String label;
  final bool selected;
  final VoidCallback onTap;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.softOrange,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 32, color: AppTheme.brandOrange),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              // The app theme makes FilledButton full width, so we set a size.
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
              onPressed: onPressed,
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}