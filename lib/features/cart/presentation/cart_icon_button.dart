import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import 'cart_cubit.dart';
import 'cart_state.dart';

// Cart icon for the top bar, with the number of items on a badge.
class CartIconButton extends StatelessWidget {
  const CartIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      // Counts only dishes that can be ordered now.
      buildWhen: (previous, current) =>
          previous.itemCount != current.itemCount ||
          previous.hasProblem != current.hasProblem,
      builder: (context, state) {
        final count = state.itemCount;
        final problem = state.hasProblem;

        return IconButton(
          tooltip: problem ? 'Cart needs your attention' : 'Cart',
          onPressed: () => context.push(AppRoutes.cart),
          icon: Badge(
            // A problem shows a red "!" in place of the number.
            isLabelVisible: problem || count > 0,
            backgroundColor:
                problem ? Colors.red.shade700 : AppTheme.brandOrange,
            textColor: Colors.white,
            label: problem
                ? const Text(
                    '!',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  )
                : Text(count > 99 ? '99+' : '$count'),
            child: const Icon(Icons.shopping_bag_outlined),
          ),
        );
      },
    );
  }
}