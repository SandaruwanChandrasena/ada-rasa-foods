import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/price_format.dart';
import '../../../../core/widgets/food_image.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../auth/domain/phone_checks.dart';
import '../../domain/food_order.dart';
import '../../domain/order_item.dart';
import '../../domain/order_status.dart';
import '../my_orders/my_orders_list.dart';

// One order on the restaurant board, with its next step buttons.
class RestaurantOrderCard extends StatelessWidget {
  const RestaurantOrderCard({
    super.key,
    required this.order,
    required this.busy,
    required this.onMove,
    required this.onCall,
  });

  // The yellow "Collect Rs. X" note, like the Add card note.
  static const Color noteBg = Color(0xFFFFF4D6);
  static const Color noteText = Color(0xFF7A5200);

  final FoodOrder order;

  // True while a step is saving. Shows a spinner, not buttons.
  final bool busy;

  final void Function(OrderStatus next) onMove;

  // Opens the phone app with the customer's number.
  final void Function(String phone) onCall;

  @override
  Widget build(BuildContext context) {
    final collect = order.status == OrderStatus.ready && !order.isCard;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(order: order),
          const _Line(),
          _Customer(order: order, onCall: onCall),
          const _Line(),
          for (final item in order.items) _ItemRow(item: item),
          const _Line(),
          Row(
            children: [
              Expanded(
                child: Text(
                  paymentText(order),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatPrice(order.total),
                style: const TextStyle(
                  color: AppTheme.brandOrange,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (collect) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: noteBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.payments_rounded,
                    size: 20,
                    color: noteText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Collect ${formatPrice(order.total)}',
                      style: const TextStyle(
                        color: noteText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
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

class _Line extends StatelessWidget {
  const _Line();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 24, thickness: 1, color: AppTheme.border);
  }
}

// Bag icon, "#ABCDEF", the time, and the status pill.
class _Header extends StatelessWidget {
  const _Header({required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SectionIcon(icon: Icons.shopping_bag_rounded, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#${order.shortNumber}',
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                RestaurantOrderCard.timeAgo(context, order.placedAt),
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: OrderStatusPill(order: order)),
      ],
    );
  }
}

// Name, phone, and a round orange call button.
class _Customer extends StatelessWidget {
  const _Customer({required this.order, required this.onCall});

  final FoodOrder order;
  final void Function(String phone) onCall;

  @override
  Widget build(BuildContext context) {
    final phone = order.customerPhone;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppTheme.softOrange,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_rounded,
            size: 20,
            color: AppTheme.brandOrange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                phone.isEmpty ? 'No phone' : PhoneChecks.format(phone),
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (phone.isNotEmpty)
          Semantics(
            button: true,
            label: 'Call',
            excludeSemantics: true,
            child: Material(
              key: const Key('call-button'),
              color: AppTheme.brandOrange,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onCall(phone),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.phone_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Photo, name, "× 2" and the line price.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          FoodImage(
            imageUrl: item.imageUrl,
            width: 44,
            height: 44,
            borderRadius: 10,
            iconSize: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.softOrange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '× ${item.quantity}',
              style: const TextStyle(
                color: AppTheme.deepOrange,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatPrice(item.price * item.quantity),
            style: const TextStyle(color: AppTheme.textDark),
          ),
        ],
      ),
    );
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
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.dangerRed,
                  backgroundColor: AppTheme.dangerBg,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _reject(context),
                child: const _IconText(
                  icon: Icons.close_rounded,
                  text: 'Reject',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StepButton(
                icon: Icons.check_rounded,
                text: 'Accept',
                onPressed: () => onMove(OrderStatus.accepted),
              ),
            ),
          ],
        ),
      OrderStatus.accepted => _StepButton(
          icon: Icons.soup_kitchen_rounded,
          text: 'Start preparing',
          onPressed: () => onMove(OrderStatus.preparing),
        ),
      OrderStatus.preparing => _StepButton(
          icon: Icons.notifications_active_rounded,
          text: 'Mark ready',
          onPressed: () => onMove(OrderStatus.ready),
        ),
      OrderStatus.ready => _StepButton(
          icon: Icons.check_rounded,
          text: 'Completed',
          onPressed: () => _complete(context),
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
              backgroundColor: danger ? AppTheme.dangerRed : null,
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

// An orange step button with an icon, like "Accept" or "Mark ready".
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.text,
    required this.onPressed,
  });

  final IconData icon;
  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      // The app theme makes FilledButton full width, so we set a size.
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onPressed: onPressed,
      child: _IconText(icon: icon, text: text),
    );
  }
}

// An icon and a word that shrinks with "..." on big fonts.
class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}