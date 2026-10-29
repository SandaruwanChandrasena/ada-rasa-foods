import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../menu/domain/dish.dart';
import '../domain/cart.dart';
import 'cart_cubit.dart';
import 'cart_state.dart';
import 'clear_cart_dialog.dart';
import 'fly_to_cart.dart';

// "Add" button that turns into a minus / amount / plus stepper (CUS-7).
class AddToCartButton extends StatelessWidget {
  const AddToCartButton({
    super.key,
    required this.dish,
    required this.restaurantName,
    required this.enabled,
  });

  final Dish dish;
  final String restaurantName;

  // False when the restaurant is closed or the dish is not available.
  // Then a grey Add shows, even if the dish is in the cart.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      // Rebuild only when this dish's amount changes.
      buildWhen: (previous, current) =>
          previous.cart.quantityOf(dish.id) !=
          current.cart.quantityOf(dish.id),
      builder: (context, state) {
        final quantity = state.cart.quantityOf(dish.id);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: quantity == 0 || !enabled
              ? _AddButton(
                  key: const ValueKey('add'),
                  onPressed: enabled ? () => _onAdd(context) : null,
                )
              : _Stepper(
                  key: const ValueKey('stepper'),
                  quantity: quantity,
                  canAdd: quantity < Cart.maxQuantity,
                  onMinus: () {
                    context.read<CartCubit>().decrease(dish.id);
                    flyToBin(context, imageUrl: dish.imageUrl);
                  },
                  onPlus: () {
                    context.read<CartCubit>().increase(dish.id);
                    flyToCart(context, imageUrl: dish.imageUrl);
                  },
                ),
        );
      },
    );
  }

  Future<void> _onAdd(BuildContext context) async {
    // Read these before any await, so we do not use context after it.
    final cubit = context.read<CartCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final result = cubit.addDish(dish, restaurantName: restaurantName);
    switch (result) {
      case AddToCartResult.added:
        flyToCart(context, imageUrl: dish.imageUrl);
      case AddToCartResult.otherRestaurant:
        final yes = await showClearCartDialog(
          context,
          currentRestaurant: cubit.state.cart.restaurantName,
        );
        if (!yes) return;
        cubit.clearAndAdd(dish, restaurantName: restaurantName);
        if (context.mounted) flyToCart(context, imageUrl: dish.imageUrl);
      case AddToCartResult.maxReached:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('You can add up to ${Cart.maxQuantity} of one dish.'),
          ),
        );
      case AddToCartResult.noUser:
        messenger.showSnackBar(
          const SnackBar(content: Text('Please sign in again to order.')),
        );
    }
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      // The app theme makes FilledButton full width, so we set a size here.
      style: FilledButton.styleFrom(
        minimumSize: const Size(80, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add'),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    super.key,
    required this.quantity,
    required this.canAdd,
    required this.onMinus,
    required this.onPlus,
  });

  final int quantity;
  final bool canAdd;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.brandOrange),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(icon: Icons.remove, tooltip: 'Less', onPressed: onMinus),
          SizedBox(
            width: 24,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            tooltip: 'More',
            onPressed: canAdd ? onPlus : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: AppTheme.brandOrange,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 34),
    );
  }
}