import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import 'my_orders_cubit.dart';
import 'my_orders_state.dart';

// Home banner: a rejected order (red) or orders still going (orange).
class ActiveOrderBanner extends StatelessWidget {
  const ActiveOrderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyOrdersCubit, MyOrdersState>(
      builder: (context, state) {
        if (state.status != MyOrdersStatus.loaded) {
          return const SizedBox.shrink();
        }

        // A rejected order comes first, so the customer cannot miss it.
        final rejected = state.unseenRejected;
        if (rejected != null) {
          return _Banner(
            icon: Icons.cancel_outlined,
            text: '${rejected.restaurantName} rejected your order. '
                'Tap to see it.',
            color: Colors.red.shade700,
            background: Colors.red.shade50,
            onTap: () {
              context.read<MyOrdersCubit>().markSeen(rejected);
              context.push(AppRoutes.orderStatus(rejected.id));
            },
          );
        }

        final active = state.activeOrders;
        if (active.isEmpty) return const SizedBox.shrink();

        if (active.length == 1) {
          final order = active.single;
          return _Banner(
            icon: Icons.receipt_long_outlined,
            text: '${order.restaurantName}: ${order.statusLabel}. '
                'Tap to see your order.',
            color: AppTheme.brandOrange,
            background: const Color(0xFFFFF1EA),
            onTap: () => context.push(AppRoutes.orderStatus(order.id)),
          );
        }

        return _Banner(
          icon: Icons.receipt_long_outlined,
          text: '${active.length} orders in progress. Tap to see them.',
          color: AppTheme.brandOrange,
          background: const Color(0xFFFFF1EA),
          onTap: () => context.push(AppRoutes.myOrders),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}