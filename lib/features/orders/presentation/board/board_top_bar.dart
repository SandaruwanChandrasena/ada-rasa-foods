import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../restaurants/presentation/owner/my_restaurant_cubit.dart';
import '../../../restaurants/presentation/owner/owner_profile_page.dart';
import 'restaurant_orders_cubit.dart';

// Green "Open" or soft red "Closed" (RES-4). Tap to switch.
// Closing asks first. Hidden until the restaurant loads.
class OpenPill extends StatelessWidget {
  const OpenPill({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MyRestaurantCubit>().state;
    final restaurant = state.restaurant;
    if (state.view != MyRestaurantView.loaded || restaurant == null) {
      return const SizedBox.shrink();
    }

    final open = restaurant.isOpen;
    final color = open ? AppTheme.successGreen : AppTheme.dangerRed;
    final background = open ? AppTheme.successBg : AppTheme.dangerBg;

    return Semantics(
      button: true,
      label: open ? 'Open, tap to close' : 'Closed, tap to open',
      excludeSemantics: true,
      child: Material(
        key: const Key('open-pill'),
        color: background,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: state.canSwitch ? () => _onTap(context, open) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.isSaving)
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                else
                  Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 6),
                Text(
                  open ? 'Open' : 'Closed',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, bool open) async {
    final cubit = context.read<MyRestaurantCubit>();
    if (!open) {
      await cubit.setOpen(true);
      return;
    }
    final yes = await askOwner(
      context,
      title: 'Close now?',
      message: 'Customers cannot order until you open again.',
      yesText: 'Close',
      danger: true,
    );
    if (yes) await cubit.setOpen(false);
  }
}

// A soft red note while closed, so the owner knows why no orders come.
class ClosedNote extends StatelessWidget {
  const ClosedNote({super.key});

  @override
  Widget build(BuildContext context) {
    final closed = context.select(
      (MyRestaurantCubit cubit) => cubit.state.restaurant?.isOpen == false,
    );
    if (!closed) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.dangerBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.storefront_rounded,
            size: 20,
            color: AppTheme.dangerRed,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Closed. No new orders come.',
              style: TextStyle(
                color: AppTheme.dangerRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// "New 2", "Active 1" and "Done" chips (RES-1). They follow the
// DefaultTabController, so a swipe moves the orange chip too.
class BoardChips extends StatelessWidget {
  const BoardChips({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    final counts = context.select(
      (RestaurantOrdersCubit cubit) => (
        cubit.state.newOrders.length,
        cubit.state.activeOrders.length,
      ),
    );
    final labels = [
      counts.$1 == 0 ? 'New' : 'New ${counts.$1}',
      counts.$2 == 0 ? 'Active' : 'Active ${counts.$2}',
      'Done',
    ];

    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, _) {
        // Changes at half way through a swipe, like a TabBar.
        final picked = controller.animation!.value.round();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < labels.length; i++)
                  _Chip(
                    label: labels[i],
                    selected: i == picked,
                    onTap: () => controller.animateTo(i),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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