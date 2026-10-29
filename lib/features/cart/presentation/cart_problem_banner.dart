import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import 'cart_cubit.dart';
import 'cart_state.dart';

// Warning when the cart has a problem. Tap it to open the cart.
class CartProblemBanner extends StatelessWidget {
  const CartProblemBanner({super.key, this.restaurantId});

  // On a restaurant page: show only if this restaurant is in the cart.
  final String? restaurantId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      buildWhen: (previous, current) =>
          previous.problemMessage != current.problemMessage ||
          previous.cart.restaurantId != current.cart.restaurantId,
      builder: (context, state) {
        final message = state.problemMessage;
        final otherRestaurant =
            restaurantId != null && restaurantId != state.cart.restaurantId;
        if (message == null || otherRestaurant) {
          return const SizedBox.shrink();
        }

        final red = Colors.red.shade700;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Material(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(AppRoutes.cart),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(message, style: TextStyle(color: red)),
                    ),
                    Icon(Icons.chevron_right, color: red),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}