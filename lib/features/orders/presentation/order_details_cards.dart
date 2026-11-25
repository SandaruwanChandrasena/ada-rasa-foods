import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';
import '../../../core/widgets/section_card.dart';
import '../domain/food_order.dart';
import '../domain/order_item.dart';
import '../domain/order_status.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// Like "25 Nov, 2:28 PM". Null while the server time is on its way.
String orderDateText(BuildContext context, DateTime? at) {
  if (at == null) return 'Just now';
  final time = TimeOfDay.fromDateTime(at).format(context);
  return '${at.day} ${_months[at.month - 1]}, $time';
}

// "Pickup from": the restaurant and when the order was placed.
class OrderPickupFromCard extends StatelessWidget {
  const OrderPickupFromCard({super.key, required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.storefront_rounded,
      title: 'Pickup from',
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
            'Placed ${orderDateText(context, order.placedAt)}',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

// "Pick up at": only when the food is ready (CUS-11).
class OrderPickupAtCard extends StatelessWidget {
  const OrderPickupAtCard({super.key, required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.brandOrange, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_rounded, color: AppTheme.brandOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pick up at',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.restaurantName,
                  style: const TextStyle(color: AppTheme.textDark),
                ),
                Text(
                  order.restaurantAddress,
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// "Your order": each dish with its amount, then the total. No photos.
class OrderItemsCard extends StatelessWidget {
  const OrderItemsCard({super.key, required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.receipt_long_rounded,
      title: 'Your order',
      child: Column(
        children: [
          for (final item in order.items) _ItemLine(item: item),
          const Divider(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                formatPrice(order.total),
                style: const TextStyle(
                  color: AppTheme.brandOrange,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.softOrange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.quantity}x',
              style: const TextStyle(
                color: AppTheme.deepOrange,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textDark),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatPrice(item.lineTotal),
            style: const TextStyle(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

// "Payment": how it was paid, or how to pay.
class OrderPaymentCard extends StatelessWidget {
  const OrderPaymentCard({super.key, required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    final total = formatPrice(order.total);
    final brand = order.cardBrand == 'mastercard' ? 'Mastercard' : 'Visa';
    final stopped = order.status == OrderStatus.rejected ||
        order.status == OrderStatus.cancelled;

    final (IconData icon, String text, Color color) =
        switch (order.paymentStatus) {
      PaymentStatus.refunded => (
          Icons.replay_rounded,
          'Refunded (demo) to $brand ending ${order.cardLast4}',
          AppTheme.successGreen,
        ),
      PaymentStatus.paid when order.isCard => (
          Icons.credit_card_rounded,
          'Paid by $brand ending ${order.cardLast4}',
          AppTheme.textDark,
        ),
      PaymentStatus.paid => (
          Icons.payments_rounded,
          'Paid in cash',
          AppTheme.textDark,
        ),
      // A stopped cash order took no money.
      PaymentStatus.pending when stopped => (
          Icons.payments_rounded,
          'No payment needed',
          AppTheme.textDark,
        ),
      PaymentStatus.pending => (
          Icons.payments_rounded,
          'Pay at pickup: $total',
          AppTheme.textDark,
        ),
    };

    return SectionCard(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Payment',
      child: Row(
        children: [
          Icon(
            icon,
            color: color == AppTheme.textDark ? AppTheme.textMuted : color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// Soft red "Cancel order". Asks first, then calls [onCancel].
class OrderCancelButton extends StatelessWidget {
  const OrderCancelButton({
    super.key,
    required this.isCancelling,
    required this.onCancel,
  });

  final bool isCancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.dangerRed,
        backgroundColor: AppTheme.dangerBg,
        disabledBackgroundColor: AppTheme.dangerBg,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      onPressed: isCancelling ? null : () => _confirm(context),
      icon: isCancelling
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.dangerRed,
              ),
            )
          : const Icon(Icons.close_rounded),
      label: const Text('Cancel order'),
    );
  }

  // A wrong tap must not cancel the order.
  Future<void> _confirm(BuildContext context) async {
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
              backgroundColor: AppTheme.dangerRed,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (yes ?? false) onCancel();
  }
}