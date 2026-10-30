import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/price_format.dart';
import '../domain/food_order.dart';
import '../domain/order_status.dart';
import 'order_status_cubit.dart';
import 'order_status_state.dart';

// One order, live: status steps, pickup address, payment, cancel (CUS-11).
class OrderStatusScreen extends StatelessWidget {
  const OrderStatusScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OrderStatusCubit>(
      create: (_) => OrderStatusCubit(sl())..start(orderId),
      child: const _OrderStatusView(),
    );
  }
}

class _OrderStatusView extends StatelessWidget {
  const _OrderStatusView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OrderStatusCubit, OrderStatusState>(
      listenWhen: (previous, current) => previous.noticeId != current.noticeId,
      listener: (context, state) {
        final notice = state.notice;
        if (notice == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(notice),
              duration: const Duration(seconds: 5),
            ),
          );
      },
      builder: (context, state) {
        final order = state.order;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              order == null ? 'Your order' : 'Order #${order.shortNumber}',
            ),
          ),
          body: switch (state.view) {
            OrderView.loading =>
              const Center(child: CircularProgressIndicator()),
            OrderView.failure => _MessageView(
                message: state.errorMessage ?? 'Something went wrong.',
                buttonText: 'Retry',
                onPressed: () => context.read<OrderStatusCubit>().retry(),
              ),
            OrderView.notFound => _MessageView(
                message: 'This order was not found.',
                buttonText: 'Go to home',
                onPressed: () => context.go(AppRoutes.customer),
              ),
            OrderView.loaded => _OrderDetails(state: state),
          },
        );
      },
    );
  }
}

class _OrderDetails extends StatelessWidget {
  const _OrderDetails({required this.state});

  final OrderStatusState state;

  @override
  Widget build(BuildContext context) {
    final order = state.order!;
    final textTheme = Theme.of(context).textTheme;
    final bold = textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final stopped = order.status == OrderStatus.rejected ||
        order.status == OrderStatus.cancelled;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _StatusHeader(order: order),
        const SizedBox(height: 16),
        if (!stopped) ...[
          _StatusSteps(current: order.status),
          const SizedBox(height: 16),
        ],
        if (order.status == OrderStatus.ready) ...[
          _PickupAddress(order: order),
          const SizedBox(height: 16),
        ],
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.storefront_outlined),
          title: Text(order.restaurantName, style: bold),
          subtitle: Text(_placedText(context, order)),
        ),
        const Divider(),
        const SizedBox(height: 8),
        Text('Your order', style: bold),
        const SizedBox(height: 8),
        for (final item in order.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    '${item.quantity} x',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Text(item.name)),
                const SizedBox(width: 12),
                Text(formatPrice(item.lineTotal)),
              ],
            ),
          ),
        const Divider(height: 24),
        Row(
          children: [
            Text('Total', style: bold),
            const Spacer(),
            Text(formatPrice(order.total), style: bold),
          ],
        ),
        const SizedBox(height: 16),
        _PaymentInfo(order: order),
        if (state.canCancel || state.isCancelling) ...[
          const SizedBox(height: 24),
          _CancelButton(isCancelling: state.isCancelling),
        ],
      ],
    );
  }

  String _placedText(BuildContext context, FoodOrder order) {
    final placedAt = order.placedAt;
    if (placedAt == null) return 'Pickup order';
    final time = TimeOfDay.fromDateTime(placedAt).format(context);
    return 'Pickup order. Placed at $time';
  }
}

// The big card at the top: what is happening now.
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    final name = order.restaurantName;
    final bad = order.status == OrderStatus.rejected ||
        order.status == OrderStatus.cancelled;
    final color =
        bad ? Colors.red.shade700 : Theme.of(context).colorScheme.primary;

    final (IconData icon, String message) = switch (order.status) {
      OrderStatus.placed => (
          Icons.receipt_long_outlined,
          'Waiting for $name to accept your order.',
        ),
      OrderStatus.accepted => (
          Icons.thumb_up_alt_outlined,
          '$name accepted your order.',
        ),
      OrderStatus.preparing => (
          Icons.soup_kitchen_outlined,
          'Your food is being prepared.',
        ),
      OrderStatus.ready => (
          Icons.shopping_bag_outlined,
          'Your food is ready. Please collect it.',
        ),
      OrderStatus.completed => (
          Icons.check_circle_outline,
          'You collected your order. Enjoy your meal!',
        ),
      OrderStatus.rejected => (
          Icons.cancel_outlined,
          'Sorry, $name could not take your order.',
        ),
      OrderStatus.cancelled => (
          Icons.cancel_outlined,
          'You cancelled this order.',
        ),
      // Stage 2 (delivery) statuses.
      _ => (Icons.delivery_dining_outlined, order.statusLabel),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bad ? Colors.red.shade50 : const Color(0xFFFFF1EA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.statusLabel,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                ),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Placed, Accepted, Preparing, Ready for pickup, Completed.
class _StatusSteps extends StatelessWidget {
  const _StatusSteps({required this.current});

  final OrderStatus current;

  @override
  Widget build(BuildContext context) {
    final orange = Theme.of(context).colorScheme.primary;
    final steps = OrderStatus.pickupSteps;
    final currentIndex = steps.indexOf(current);

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  i < currentIndex || current == OrderStatus.completed
                      ? Icons.check_circle
                      : i == currentIndex
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                  color: i <= currentIndex ? orange : Colors.grey.shade400,
                ),
                const SizedBox(width: 12),
                Text(
                  steps[i].labelFor(Fulfillment.pickup),
                  style: TextStyle(
                    fontWeight:
                        i == currentIndex ? FontWeight.w700 : FontWeight.w400,
                    color: i <= currentIndex
                        ? Colors.black87
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Shown when the food is ready (CUS-11).
class _PickupAddress extends StatelessWidget {
  const _PickupAddress({required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    final orange = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: orange, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined, color: orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pick up your food at',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(order.restaurantName),
                Text(order.restaurantAddress),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentInfo extends StatelessWidget {
  const _PaymentInfo({required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    final total = formatPrice(order.total);
    final brand = order.cardBrand == 'mastercard' ? 'Mastercard' : 'Visa';
    final stopped = order.status == OrderStatus.rejected ||
        order.status == OrderStatus.cancelled;

    final (IconData icon, String text) = switch (order.paymentStatus) {
      PaymentStatus.refunded => (
          Icons.replay,
          'Refunded (demo) to $brand ending ${order.cardLast4}',
        ),
      PaymentStatus.paid when order.isCard => (
          Icons.credit_card,
          'Paid by $brand ending ${order.cardLast4}',
        ),
      PaymentStatus.paid => (Icons.payments_outlined, 'Paid in cash'),
      // A stopped cash order took no money.
      PaymentStatus.pending when stopped => (
          Icons.payments_outlined,
          'No payment needed',
        ),
      PaymentStatus.pending => (
          Icons.payments_outlined,
          'Pay at pickup: $total',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.isCancelling});

  final bool isCancelling;

  @override
  Widget build(BuildContext context) {
    final red = Colors.red.shade700;

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: red,
        side: BorderSide(color: red),
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: isCancelling ? null : () => _confirmCancel(context),
      child: isCancelling
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : const Text('Cancel order'),
    );
  }

  // Asks first, so a wrong tap does not cancel the order.
  Future<void> _confirmCancel(BuildContext context) async {
    final cubit = context.read<OrderStatusCubit>();

    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text('The restaurant will not make this order.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            // The app theme makes FilledButton full width, so we set a size.
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 40),
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (yes ?? false) await cubit.cancel();
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }
}