import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';
import '../domain/food_order.dart';
import '../domain/order_status.dart';
import 'my_orders_state.dart';
import 'order_details_cards.dart';

// The My orders tab body: Active and Past groups, newest first.
class MyOrdersList extends StatelessWidget {
  const MyOrdersList({
    super.key,
    required this.state,
    required this.onOpen,
    required this.onRetry,
    required this.onBrowse,
  });

  final MyOrdersState state;
  final ValueChanged<FoodOrder> onOpen;
  final VoidCallback onRetry;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case MyOrdersStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case MyOrdersStatus.failure:
        return _MessageView(
          icon: Icons.wifi_off_rounded,
          title: state.errorMessage ?? 'Something went wrong.',
          buttonText: 'Retry',
          onPressed: onRetry,
        );

      case MyOrdersStatus.loaded:
        if (state.orders.isEmpty) {
          return _MessageView(
            icon: Icons.receipt_long_rounded,
            title: 'No orders yet',
            buttonText: 'Browse restaurants',
            onPressed: onBrowse,
          );
        }
        final active = state.activeOrders;
        final past =
            state.orders.where((order) => order.status.isEnd).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (active.isNotEmpty) ...[
              const _GroupTitle('Active'),
              for (final order in active) _row(order),
            ],
            if (past.isNotEmpty) ...[
              const _GroupTitle('Past'),
              for (final order in past) _row(order),
            ],
          ],
        );
    }
  }

  Widget _row(FoodOrder order) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MyOrderRow(
        key: ValueKey('order_${order.id}'),
        order: order,
        onTap: () => onOpen(order),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// One order: shop icon, name, number and time, items and price, status.
class MyOrderRow extends StatelessWidget {
  const MyOrderRow({super.key, required this.order, required this.onTap});

  final FoodOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = order.itemCount;
    final radius = BorderRadius.circular(16);

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.softOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppTheme.brandOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${order.shortNumber} · '
                      '${orderDateText(context, order.placedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        text: '$count ${count == 1 ? 'item' : 'items'} · ',
                        children: [
                          TextSpan(
                            text: formatPrice(order.total),
                            style: const TextStyle(
                              color: AppTheme.brandOrange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // A long status like "Ready for pickup" shrinks with "...".
              Flexible(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OrderStatusPill(order: order),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Like the status card: orange going, green ready or done, red stopped.
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    final (Color text, Color background) = switch (order.status) {
      OrderStatus.ready ||
      OrderStatus.completed ||
      OrderStatus.delivered =>
        (AppTheme.successGreen, AppTheme.successBg),
      OrderStatus.rejected ||
      OrderStatus.cancelled =>
        (AppTheme.dangerRed, AppTheme.dangerBg),
      _ => (AppTheme.deepOrange, AppTheme.softOrange),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        order.statusLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
    required this.title,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppTheme.softOrange,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppTheme.brandOrange),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }
}