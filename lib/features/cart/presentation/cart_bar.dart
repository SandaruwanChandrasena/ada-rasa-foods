import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';
import 'cart_cubit.dart';
import 'cart_state.dart';

// Bar at the bottom with the count and total. Slides up when the cart
// gets its first dish, and down when it is empty (CUS-7).
class CartBar extends StatelessWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      buildWhen: (previous, current) =>
          previous.cart.isEmpty != current.cart.isEmpty ||
          previous.itemCount != current.itemCount ||
          previous.total != current.total ||
          previous.hasProblem != current.hasProblem,
      builder: (context, state) {
        final show = !state.cart.isEmpty;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
          // Same key while shown, so a new count does not slide again.
          child: show
              ? _Bar(key: const ValueKey('bar'), state: state)
              : const SizedBox.shrink(key: ValueKey('none')),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({super.key, required this.state});

  final CartState state;

  @override
  Widget build(BuildContext context) {
    final problem = state.hasProblem;
    final count = state.itemCount;
    final text = problem
        ? 'Your cart needs attention'
        : '$count ${count == 1 ? 'item' : 'items'}  ·  '
            '${formatPrice(state.total)}';

    const white = TextStyle(color: Colors.white, fontWeight: FontWeight.w600);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Material(
          // Red when the cart has a problem, like the badge.
          color: problem ? Colors.red.shade700 : AppTheme.brandOrange,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push(AppRoutes.cart),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    problem
                        ? Icons.warning_amber_rounded
                        : Icons.shopping_bag_outlined,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text, style: white)),
                  const Text('View cart', style: white),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}