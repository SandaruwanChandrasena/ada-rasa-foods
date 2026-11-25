import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';
import '../../../core/widgets/section_card.dart';
import '../../cart/domain/cart_item.dart';

// "Pickup from": the restaurant the customer collects the food from.
class CheckoutPickupCard extends StatelessWidget {
  const CheckoutPickupCard({super.key, required this.restaurantName});

  final String restaurantName;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.storefront_rounded,
      title: 'Pickup from',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            restaurantName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'You collect it yourself',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

// "Your order": each dish with its amount, then the total. No photos.
class CheckoutOrderCard extends StatelessWidget {
  const CheckoutOrderCard({
    super.key,
    required this.items,
    required this.total,
  });

  final List<CartItem> items;

  // Whole rupees.
  final int total;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.receipt_long_rounded,
      title: 'Your order',
      child: Column(
        children: [
          for (final item in items) _OrderLine(item: item),
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
                formatPrice(total),
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

class _OrderLine extends StatelessWidget {
  const _OrderLine({required this.item});

  final CartItem item;

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
          // A long name shrinks with "..."; the price always shows.
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

// Soft red note at the top when the order can't be placed now.
class CheckoutProblemBanner extends StatelessWidget {
  const CheckoutProblemBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_rounded, color: AppTheme.dangerRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.dangerRed),
            ),
          ),
        ],
      ),
    );
  }
}

// The big button: "Place order · Rs. X", or a spinner while placing.
class PlaceOrderButton extends StatelessWidget {
  const PlaceOrderButton({
    super.key,
    required this.total,
    required this.onPressed,
    this.placing = false,
  });

  // Whole rupees.
  final int total;

  // Null makes the button grey.
  final VoidCallback? onPressed;

  final bool placing;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      child: placing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The words can shrink with "..."; the total always shows.
                const Flexible(
                  child: Text(
                    'Place order',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(' · ${formatPrice(total)}'),
              ],
            ),
    );
  }
}