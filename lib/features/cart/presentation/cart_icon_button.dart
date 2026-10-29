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
      buildWhen: (previous, current) =>
          previous.cart.itemCount != current.cart.itemCount,
      builder: (context, state) {
        final count = state.cart.itemCount;

        return IconButton(
          tooltip: 'Cart',
          onPressed: () => context.push(AppRoutes.cart),
          icon: Badge(
            isLabelVisible: count > 0,
            backgroundColor: AppTheme.brandOrange,
            textColor: Colors.white,
            label: Text(count > 99 ? '99+' : '$count'),
            child: const Icon(Icons.shopping_bag_outlined),
          ),
        );
      },
    );
  }
}