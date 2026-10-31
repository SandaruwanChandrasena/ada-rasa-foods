import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/price_format.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../cart/presentation/cart_cubit.dart';
import '../../cart/presentation/cart_state.dart';
import 'checkout_cubit.dart';
import 'checkout_state.dart';

// Checkout: check the order, pick how to pay, and place it (CUS-4).
class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CheckoutCubit>(
      create: (_) => CheckoutCubit(sl(), sl()),
      child: const _CheckoutView(),
    );
  }
}

class _CheckoutView extends StatelessWidget {
  const _CheckoutView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CheckoutCubit, CheckoutState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: _onCheckoutChanged,
      builder: (context, checkout) {
        // Back is blocked while placing, so the cart is always cleared.
        return PopScope(
          canPop: !checkout.isPlacing,
          child: BlocBuilder<CartCubit, CartState>(
            builder: (context, cart) {
              final placed = checkout.status == CheckoutStatus.placed;

              return Scaffold(
                appBar: AppBar(title: const Text('Checkout')),
                body: cart.cart.isEmpty && !placed
                    ? const _EmptyCheckout()
                    : _OrderSummary(cart: cart),
                bottomNavigationBar: cart.cart.isEmpty
                    ? null
                    : _PlaceOrderBar(cart: cart, checkout: checkout),
              );
            },
          ),
        );
      },
    );
  }

  void _onCheckoutChanged(BuildContext context, CheckoutState state) {
    final messenger = ScaffoldMessenger.of(context);

    switch (state.status) {
      case CheckoutStatus.placed:
        final orderId = state.orderId;
        if (orderId == null) return;
        final cartCubit = context.read<CartCubit>();
        // go() replaces checkout, so Back goes home, not to checkout.
        context.go(AppRoutes.orderStatus(orderId));
        cartCubit.clear();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Your order is placed.'),
              duration: Duration(seconds: 3),
            ),
          );
      case CheckoutStatus.failure:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Please try again.'),
              duration: const Duration(seconds: 5),
            ),
          );
      case CheckoutStatus.ready:
      case CheckoutStatus.placing:
        break;
    }
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bold = textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final problem = cart.canCheckout ? null : cart.problemMessage;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (problem != null) _ProblemBanner(message: problem),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.storefront_outlined),
          title: Text(cart.cart.restaurantName, style: bold),
          subtitle: const Text('Pickup order. You collect it yourself.'),
        ),
        const Divider(),
        const SizedBox(height: 8),
        Text('Your order', style: bold),
        const SizedBox(height: 8),
        for (final item in cart.cart.items)
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
            Text(formatPrice(cart.total), style: bold),
          ],
        ),
        const SizedBox(height: 24),
        Text('Payment', style: bold),
        const SizedBox(height: 8),
        const _CashOption(),
        // Card payment joins here in Part 7. For now, manage saved cards.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.push(AppRoutes.myCards),
            icon: const Icon(Icons.credit_card_outlined),
            label: const Text('Manage cards'),
          ),
        ),
      ],
    );
  }
}

// The only choice for now. Saved cards come in Part 7.
class _CashOption extends StatelessWidget {
  const _CashOption();

  @override
  Widget build(BuildContext context) {
    final orange = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: orange, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(Icons.payments_outlined, color: orange),
        title: const Text('Cash at pickup'),
        subtitle: const Text('Pay when you collect your food.'),
        trailing: Icon(Icons.check_circle, color: orange),
      ),
    );
  }
}

class _ProblemBanner extends StatelessWidget {
  const _ProblemBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _PlaceOrderBar extends StatelessWidget {
  const _PlaceOrderBar({required this.cart, required this.checkout});

  final CartState cart;
  final CheckoutState checkout;

  @override
  Widget build(BuildContext context) {
    final canPlace = cart.canCheckout &&
        !checkout.isPlacing &&
        checkout.status != CheckoutStatus.placed;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: FilledButton(
          onPressed: canPlace ? () => _place(context) : null,
          child: checkout.isPlacing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text('Place order'),
        ),
      ),
    );
  }

  void _place(BuildContext context) {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    context.read<CheckoutCubit>().placeOrder(user: user, cart: cart);
  }
}

class _EmptyCheckout extends StatelessWidget {
  const _EmptyCheckout();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your cart is empty.'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.customer),
              child: const Text('Browse restaurants'),
            ),
          ],
        ),
      ),
    );
  }
}