import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/price_format.dart';
import '../../../core/widgets/food_image.dart';
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
                TextButton(
                  onPressed: () => _confirmClear(context),
                  child: const Text('Clear cart'),
                ),
            ],
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : cart.isEmpty
                  ? const _EmptyCart()
                  : _CartList(state: state),
          bottomNavigationBar: cart.isEmpty ? null : _TotalBar(state: state),
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
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _RestaurantBanner(state: state),
        // Tap the restaurant name to add more food from it.
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.storefront_outlined),
          title: Text(
            cart.restaurantName,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text('Pickup order'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              context.push(AppRoutes.restaurantPage(cart.restaurantId)),
        ),
        const Divider(),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
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

  final CartItem item;
  final String restaurantId;
  final String restaurantName;

  // False when the dish (or the whole restaurant) is not available.
  final bool available;

  // A closed restaurant fades every dish, but they still count.
  final bool restaurantClosed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // The same stepper as on the menu, so the app has one stepper.
    final dish = Dish(
      id: item.dishId,
      restaurantId: restaurantId,
      name: item.name,
      price: item.price,
      category: '',
      imageUrl: item.imageUrl,
    );

    final details = Row(
      children: [
        FoodImage(
          imageUrl: item.imageUrl,
          width: 64,
          height: 64,
          iconSize: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${formatPrice(item.price)} each',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatPrice(item.lineTotal),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  // A crossed-out price is not in the total.
                  decoration: available ? null : TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final faded = !available || restaurantClosed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: !faded
                ? details
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Opacity(opacity: 0.4, child: details),
                      if (!available) ...[
                        const SizedBox(height: 6),
                        const _NotAvailableLabel(),
                      ],
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
            icon: const Icon(Icons.delete_outline),
            color: available ? Colors.grey.shade700 : Colors.red.shade700,
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

class _NotAvailableLabel extends StatelessWidget {
  const _NotAvailableLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade700,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Not available now',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.state});

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
    final textTheme = Theme.of(context).textTheme;
    final count = state.itemCount;
    final reason = _reason;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  '$count ${count == 1 ? 'item' : 'items'}',
                  style: textTheme.bodyMedium,
                ),
                const Spacer(),
                Text(
                  'Total  ${formatPrice(state.total)}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (reason != null) ...[
              const SizedBox(height: 8),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.red.shade700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              // Checkout comes with the next feature (CUS-4).
              onPressed: reason != null
                  ? null
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Checkout is coming soon.'),
                        ),
                      ),
              child: const Text('Checkout'),
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
            Icon(
              Icons.shopping_bag_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text('Your cart is empty.'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Browse restaurants'),
            ),
          ],
        ),
      ),
    );
  }
}