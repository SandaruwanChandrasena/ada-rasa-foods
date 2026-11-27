import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/section_card.dart';
import '../../orders/presentation/board/board_top_bar.dart';
import '../../restaurants/presentation/home/home_header.dart';
import '../../restaurants/presentation/owner/my_restaurant_cubit.dart';
import 'dashboard_cards.dart';
import 'owner_dashboard_cubit.dart';
import 'owner_dashboard_state.dart';
import 'sales_chart.dart';

// The owner's Home tab: the numbers of a period, live.
class OwnerDashboardView extends StatelessWidget {
  const OwnerDashboardView({super.key, this.onOpenBoard});

  // The Orders board chips, in their order.
  static const newChip = 0;
  static const activeChip = 1;
  static const doneChip = 2;

  static const chartTitle = 'Sales, last 7 days';

  // Opens the Orders tab on a chip. Null: nothing can be tapped.
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
    final shopName = context.select(
      (MyRestaurantCubit cubit) => cubit.state.restaurant?.name ?? '',
    );

    VoidCallback? tapFor(int chip) => open == null ? null : () => open(chip);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        HeroCard(
          shopName: shopName,
          summary: summary,
          period: state.period,
          onPick: (p) => context.read<OwnerDashboardCubit>().pickPeriod(p),
          onDone: tapFor(OwnerDashboardView.doneChip),
        ),
        const SizedBox(height: 12),
        SectionCard(
          icon: Icons.bar_chart_rounded,
          title: OwnerDashboardView.chartTitle,
          child: WeekSalesChart(
            sales: state.weekSales,
            today: state.today ?? DateTime.now(),
          ),
        ),
        const SizedBox(height: 12),
        StatusPills(
          summary: summary,
          onNew: tapFor(OwnerDashboardView.newChip),
          onActive: tapFor(OwnerDashboardView.activeChip),
        ),
        const SizedBox(height: 12),
        TopDishesCard(dishes: summary.topDishes, period: state.period),
      ],
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