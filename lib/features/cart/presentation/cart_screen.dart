import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/price_format.dart';
import '../../../core/widgets/food_image.dart';
import '../../menu/domain/dish.dart';
import '../domain/cart.dart';
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
                  : _CartList(cart: cart),
          bottomNavigationBar: cart.isEmpty ? null : _TotalBar(cart: cart),
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
  const _CartList({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
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
          _CartItemRow(item: item, cart: cart),
      ],
    );
  }
}

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({required this.item, required this.cart});

  final CartItem item;
  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // The same stepper as on the menu, so the app has one stepper.
    final dish = Dish(
      id: item.dishId,
      restaurantId: cart.restaurantId,
      name: item.name,
      price: item.price,
      category: '',
      imageUrl: item.imageUrl,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
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
                  ),
                ),
              ],
            ),
          ),
          AddToCartButton(
            dish: dish,
            restaurantName: cart.restaurantName,
            enabled: true,
          ),
        ],
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final count = cart.itemCount;

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
                  'Total  ${formatPrice(cart.total)}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              // Checkout comes with the next feature (CUS-4).
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checkout is coming soon.')),
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