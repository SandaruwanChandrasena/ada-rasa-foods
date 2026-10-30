import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';
import '../domain/food_order.dart';
import '../domain/order_status.dart';
import 'my_orders_cubit.dart';
import 'my_orders_state.dart';

// My orders: newest first, live. Tap one to see its status.
class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The same cubit as the home banner, so both stay in step.
    return BlocProvider<MyOrdersCubit>.value(
      value: sl<MyOrdersCubit>(),
      child: Scaffold(
        appBar: AppBar(title: const Text('My orders')),
        body: BlocBuilder<MyOrdersCubit, MyOrdersState>(
          builder: (context, state) {
            switch (state.status) {
              case MyOrdersStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case MyOrdersStatus.failure:
                return _MessageView(
                  icon: Icons.wifi_off_rounded,
                  message: state.errorMessage ?? 'Something went wrong.',
                  buttonText: 'Retry',
                  onPressed: () => context.read<MyOrdersCubit>().retry(),
                );
              case MyOrdersStatus.loaded:
                if (state.orders.isEmpty) {
                  return _MessageView(
                    icon: Icons.receipt_long_outlined,
                    message: 'You have no orders yet.',
                    buttonText: 'Browse restaurants',
                    onPressed: () => context.go(AppRoutes.customer),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: state.orders.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = state.orders[index];
                    return _OrderRow(
                      order: order,
                      onTap: () {
                        context.read<MyOrdersCubit>().markSeen(order);
                        context.push(AppRoutes.orderStatus(order.id));
                      },
                    );
                  },
                );
            }
          },
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onTap});

  final FoodOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final grey = textTheme.bodySmall?.copyWith(color: Colors.grey.shade600);
    final count = order.itemCount;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.restaurantName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusChip(order: order),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Order #${order.shortNumber}  |  '
                '${_dateText(context, order.placedAt)}',
                style: grey,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('$count ${count == 1 ? 'item' : 'items'}'),
                  const Spacer(),
                  Text(
                    formatPrice(order.total),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Like "30 Oct, 2:28 PM". Null while the server time is on its way.
  String _dateText(BuildContext context, DateTime? placedAt) {
    if (placedAt == null) return 'Just now';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final time = TimeOfDay.fromDateTime(placedAt).format(context);
    return '${placedAt.day} ${months[placedAt.month - 1]}, $time';
  }
}

// Orange while going, green when completed, red when stopped.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    final (Color text, Color background) = switch (order.status) {
      OrderStatus.completed || OrderStatus.delivered => (
          Colors.green.shade800,
          Colors.green.shade50,
        ),
      OrderStatus.rejected || OrderStatus.cancelled => (
          Colors.red.shade700,
          Colors.red.shade50,
        ),
      _ => (AppTheme.brandOrange, const Color(0xFFFFF1EA)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        order.statusLabel,
        style: TextStyle(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String message;
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
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }
}