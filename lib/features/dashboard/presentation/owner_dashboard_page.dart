import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';
import '../../orders/presentation/board/board_top_bar.dart';
import '../../restaurants/presentation/home/home_header.dart';
import '../../restaurants/presentation/owner/my_restaurant_cubit.dart';
import 'dashboard_cards.dart';
import 'owner_dashboard_cubit.dart';
import 'owner_dashboard_state.dart';

// The owner's Home tab: today's numbers, live.
class OwnerDashboardView extends StatelessWidget {
  const OwnerDashboardView({super.key, this.onOpenBoard});

  // The Orders board chips, in their order.
  static const newChip = 0;
  static const activeChip = 1;
  static const doneChip = 2;

  // Opens the Orders tab on a chip. Null: the cards can't be tapped.
  final void Function(int chip)? onOpenBoard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const HomeGreeting(),
        centerTitle: false,
        actions: const [OpenPill(), SizedBox(width: 16)],
      ),
      body: BlocBuilder<OwnerDashboardCubit, OwnerDashboardState>(
        builder: (context, state) {
          switch (state.view) {
            case DashboardView.loading:
              return const Center(child: CircularProgressIndicator());
            case DashboardView.failure:
              return _FailureView(
                message: state.errorMessage ?? 'Something went wrong.',
              );
            case DashboardView.loaded:
              return _Numbers(state: state, onOpenBoard: onOpenBoard);
          }
        },
      ),
    );
  }
}

class _Numbers extends StatelessWidget {
  const _Numbers({required this.state, required this.onOpenBoard});

  final OwnerDashboardState state;
  final void Function(int chip)? onOpenBoard;

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    final open = onOpenBoard;

    VoidCallback? tapFor(int chip) => open == null ? null : () => open(chip);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        const _ShopLine(),
        const SizedBox(height: 12),
        _Pair(
          left: StatCard(
            key: const Key('stat-sales'),
            icon: Icons.payments_rounded,
            label: 'Sales',
            value: formatPrice(summary.sales),
            tone: StatTone.green,
          ),
          right: StatCard(
            key: const Key('stat-done'),
            icon: Icons.check_circle_rounded,
            label: 'Done',
            value: '${summary.doneCount}',
            tone: StatTone.green,
            onTap: tapFor(OwnerDashboardView.doneChip),
          ),
        ),
        const SizedBox(height: 12),
        _Pair(
          left: StatCard(
            key: const Key('stat-new'),
            icon: Icons.notifications_active_rounded,
            label: 'New',
            value: '${summary.newCount}',
            onTap: tapFor(OwnerDashboardView.newChip),
          ),
          right: StatCard(
            key: const Key('stat-active'),
            icon: Icons.soup_kitchen_rounded,
            label: 'Active',
            value: '${summary.activeCount}',
            onTap: tapFor(OwnerDashboardView.activeChip),
          ),
        ),
        const SizedBox(height: 12),
        DroppedRow(count: summary.droppedCount),
        const SizedBox(height: 12),
        TopDishesCard(dishes: summary.topDishes),
      ],
    );
  }
}

// Two cards side by side.
class _Pair extends StatelessWidget {
  const _Pair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

// "Kottu Corner · Today", or just "Today" until the shop loads.
class _ShopLine extends StatelessWidget {
  const _ShopLine();

  @override
  Widget build(BuildContext context) {
    final name = context.select(
      (MyRestaurantCubit cubit) => cubit.state.restaurant?.name ?? '',
    );

    return Text(
      name.isEmpty ? 'Today' : '$name · Today',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: AppTheme.textMuted),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.read<OwnerDashboardCubit>().retry(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}