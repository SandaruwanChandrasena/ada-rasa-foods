import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';
import '../../../core/widgets/food_image.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../menu/domain/dish.dart';
import '../domain/cart_item.dart';
import 'add_to_cart_button.dart';
import 'cart_cubit.dart';
import 'cart_state.dart';

// The cart: dishes, amounts, total, and Checkout (CUS-3).
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        final cart = state.cart;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Your cart'),
            actions: [
              if (!cart.isEmpty)
                RoundIconButton(
                  icon: Icons.delete_sweep_rounded,
                  tooltip: 'Clear cart',
                  style: RoundIconStyle.danger,
                  onPressed: () => _confirmClear(context),
                ),
              const SizedBox(width: 4),
            ],
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : cart.isEmpty
                  ? const _EmptyCart()
                  : _CartList(state: state),
          bottomNavigationBar: cart.isEmpty ? null : _CheckoutBar(state: state),
        );
      },
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final cubit = context.read<CartCubit>();

    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear your cart?'),
        content: const Text('All dishes will be removed from your cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            // The app theme makes FilledButton full width, so we set a size.
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (yes ?? false) cubit.clear();
  }
}

class _CartList extends StatelessWidget {
  const _CartList({required this.state});

  final CartState state;

  @override
  Widget build(BuildContext context) {
    final cart = state.cart;
    final count = state.itemCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _RestaurantBanner(state: state),
        _RestaurantCard(
          name: cart.restaurantName,
          // Opens the menu, to add more food from it.
          onTap: () =>
              context.push(AppRoutes.restaurantPage(cart.restaurantId)),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                for (final item in cart.items)
                  _CartItemRow(
                    item: item,
                    restaurantId: cart.restaurantId,
                    restaurantName: cart.restaurantName,
                    available: state.isDishAvailable(item.dishId),
                    restaurantClosed:
                        state.restaurantStatus == CartRestaurantStatus.closed,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          icon: Icons.receipt_long_rounded,
          title: 'Order summary',
          child: Column(
            children: [
              _SummaryLine(
                label: '$count ${count == 1 ? 'item' : 'items'}',
                value: formatPrice(state.total),
              ),
              const Divider(height: 20),
              _SummaryLine(
                label: 'Total',
                value: formatPrice(state.total),
                isTotal: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isTotal ? AppTheme.textDark : AppTheme.textMuted,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? AppTheme.brandOrange : AppTheme.textMuted,
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// The restaurant the cart is from. Tap it to add more food.
class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const SectionIcon(icon: Icons.storefront_rounded, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Pickup order',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Shows when the restaurant is closed or not available.
class _RestaurantBanner extends StatelessWidget {
  const _RestaurantBanner({required this.state});

  final CartState state;

  @override
  Widget build(BuildContext context) {
    final name = state.cart.restaurantName;
    final String message;

    switch (state.restaurantStatus) {
      case CartRestaurantStatus.closed:
        message = '$name is closed now. You can order when it opens.';
      case CartRestaurantStatus.unavailable:
        message = '$name is not available now. Please clear your cart.';
      case CartRestaurantStatus.checking:
      case CartRestaurantStatus.open:
        return const SizedBox.shrink();
    }

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

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({
    required this.item,
    required this.restaurantId,
    required this.restaurantName,
    required this.available,
    required this.restaurantClosed,
  });

  static const double photoSize = 56;

  // Makes the photo of a dish that cannot be ordered look faded.
  static const Color fade = Color(0x99FFFFFF);

  final CartItem item;
  final String restaurantId;
  final String restaurantName;

  // False when the dish (or the whole restaurant) is not available.
  final bool available;

  // A closed restaurant fades every dish, but they still count.
  final bool restaurantClosed;

  @override
  Widget build(BuildContext context) {
    // The same stepper as on the menu, so the app has one stepper.
    final dish = Dish(
      id: item.dishId,
      restaurantId: restaurantId,
      name: item.name,
      price: item.price,
      category: '',
      imageUrl: item.imageUrl,
    );

    final faded = !available || restaurantClosed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // A layer, not Opacity, so the list stays smooth.
          Stack(
            children: [
              FoodImage(
                imageUrl: item.imageUrl,
                width: photoSize,
                height: photoSize,
                borderRadius: 12,
                iconSize: 24,
              ),
              if (faded)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fade,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!available) ...[
                  const _NotAvailableLabel(),
                  const SizedBox(height: 4),
                ],
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: faded ? AppTheme.textMuted : AppTheme.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatPrice(item.lineTotal),
                  style: TextStyle(
                    color: faded ? AppTheme.textMuted : AppTheme.brandOrange,
                    fontWeight: FontWeight.w700,
                    // A crossed-out price is not in the total.
                    decoration: available ? null : TextDecoration.lineThrough,
                  ),
                ),
                if (item.quantity > 1)
                  Text(
                    '${formatPrice(item.price)} each',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (!faded)
            AddToCartButton(
              dish: dish,
              restaurantName: restaurantName,
              enabled: true,
            ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_rounded),
            color: AppTheme.dangerRed,
            onPressed: () => _confirmRemove(context),
          ),
        ],
      ),
    );
  }

  // Asks first, so a wrong tap does not remove a dish.
  Future<void> _confirmRemove(BuildContext context) async {
    final cubit = context.read<CartCubit>();

    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${item.name}?'),
        content: const Text('This dish will be removed from your cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            // The app theme makes FilledButton full width, so we set a size.
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes ?? false) cubit.remove(item.dishId);
  }
}

// "Not available now" in soft red, like on the menu.
class _NotAvailableLabel extends StatelessWidget {
  const _NotAvailableLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        color: AppTheme.dangerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel_rounded, size: 14, color: AppTheme.dangerRed),
          SizedBox(width: 3),
          // Shrinks with "..." on a narrow row, so it never overflows.
          Flexible(
            child: Text(
              'Not available now',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.dangerRed,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// The big orange Checkout button with the total in it.
class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.state});

  final CartState state;

  // Why Checkout is off. Null means Checkout can be used.
  String? get _reason {
    if (state.canCheckout) return null;
    switch (state.restaurantStatus) {
      case CartRestaurantStatus.checking:
        return 'Checking the restaurant...';
      case CartRestaurantStatus.closed:
        return 'The restaurant is closed now.';
      case CartRestaurantStatus.unavailable:
        return 'The restaurant is not available now.';
      case CartRestaurantStatus.open:
        return 'Remove the dishes that are not available to checkout.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = _reason;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reason != null) ...[
              Text(
                reason,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.dangerRed,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: reason != null
                  ? null
                  : () => context.push(AppRoutes.checkout),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                // The word can shrink with "..."; the total always shows.
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Checkout',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(formatPrice(state.total)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              child: const Icon(
                Icons.shopping_cart_rounded,
                size: 48,
                color: AppTheme.brandOrange,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your cart is empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            FilledButton(
              // The app theme makes FilledButton full width, so we set a size.
              style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
              onPressed: () => context.pop(),
              child: const Text('Browse restaurants'),
            ),
          ],
        ),
      ),
    );
  }
}