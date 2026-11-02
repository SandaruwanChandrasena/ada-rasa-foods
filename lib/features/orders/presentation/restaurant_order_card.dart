import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';
import '../domain/food_order.dart';
import '../domain/order_status.dart';

// One order on the restaurant board, with its next step buttons.
class RestaurantOrderCard extends StatelessWidget {
  const RestaurantOrderCard({
    super.key,
    required this.order,
    required this.busy,
    required this.onMove,
  });

  final FoodOrder order;

  // True while a step is saving. Shows a spinner, not buttons.
  final bool busy;

  final void Function(OrderStatus next) onMove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final grey = textTheme.bodySmall?.copyWith(color: Colors.grey.shade600);
    final bold = textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Order #${order.shortNumber}', style: bold),
              ),
              _StatusChip(order: order),
            ],
          ),
          const SizedBox(height: 2),
          Text(timeAgo(context, order.placedAt), style: grey),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(order.customerName)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.customerPhone.isEmpty
                      ? 'No phone'
                      : order.customerPhone,
                  style: order.customerPhone.isEmpty ? grey : null,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('${item.quantity} x ${item.name}'),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text(paymentText(order), style: grey)),
              Text(formatPrice(order.total), style: bold),
            ],
          ),
          if (order.status == OrderStatus.ready && !order.isCard) ...[
            const SizedBox(height: 8),
            Text(
              'Collect ${formatPrice(order.total)}',
              style: bold?.copyWith(color: AppTheme.brandOrange),
            ),
          ],
          if (!order.status.isEnd) ...[
            const SizedBox(height: 12),
            _Buttons(order: order, busy: busy, onMove: onMove),
          ],
        ],
      ),
    );
  }

  // Like "Cash, pay at pickup" or "Refunded (demo)".
  static String paymentText(FoodOrder order) {
    return switch ((order.paymentMethod, order.paymentStatus)) {
      (_, PaymentStatus.refunded) => 'Refunded (demo)',
      (PaymentMethod.cash, PaymentStatus.pending) => 'Cash, pay at pickup',
      (PaymentMethod.cash, PaymentStatus.paid) => 'Cash, paid',
      (PaymentMethod.card, _) => 'Card, paid',
    };
  }

  // Like "Just now", "5 min ago", or "2:28 PM" after an hour.
  static String timeAgo(BuildContext context, DateTime? placedAt) {
    if (placedAt == null) return 'Just now';
    final minutes = DateTime.now().difference(placedAt).inMinutes;
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return '$minutes min ago';
    return TimeOfDay.fromDateTime(placedAt).format(context);
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.order,
    required this.busy,
    required this.onMove,
  });

  final FoodOrder order;
  final bool busy;
  final void Function(OrderStatus next) onMove;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    return switch (order.status) {
      OrderStatus.placed => Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () => _reject(context),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                // The app theme makes FilledButton full width.
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () => onMove(OrderStatus.accepted),
                child: const Text('Accept'),
              ),
            ),
          ],
        ),
      OrderStatus.accepted => FilledButton(
          onPressed: () => onMove(OrderStatus.preparing),
          child: const Text('Start preparing'),
        ),
      OrderStatus.preparing => FilledButton(
          onPressed: () => onMove(OrderStatus.ready),
          child: const Text('Mark ready'),
        ),
      OrderStatus.ready => FilledButton(
          onPressed: () => _complete(context),
          child: const Text('Completed'),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  Future<void> _reject(BuildContext context) async {
    final refund = order.isCard && order.paymentStatus == PaymentStatus.paid;
    final yes = await _ask(
      context,
      title: 'Reject order #${order.shortNumber}?',
      message: refund
          ? '${formatPrice(order.total)} will be refunded to the card '
              '(demo). You cannot undo this.'
          : 'The customer will see that the order is rejected. '
              'You cannot undo this.',
      noText: 'Keep',
      yesText: 'Reject',
      danger: true,
    );
    if (yes) onMove(OrderStatus.rejected);
  }

  // A cash order asks first, so the owner remembers to take the money.
  Future<void> _complete(BuildContext context) async {
    if (order.isCard) {
      onMove(OrderStatus.completed);
      return;
    }
    final yes = await _ask(
      context,
      title: 'Did you collect ${formatPrice(order.total)}?',
      message: 'Tap Completed after the customer pays and takes the food.',
      noText: 'Not yet',
      yesText: 'Completed',
    );
    if (yes) onMove(OrderStatus.completed);
  }

  Future<bool> _ask(
    BuildContext context, {
    required String title,
    required String message,
    required String noText,
    required String yesText,
    bool danger = false,
  }) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(noText),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 40),
              backgroundColor: danger ? Colors.red.shade700 : null,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(yesText),
          ),
        ],
      ),
    );
    return yes ?? false;
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