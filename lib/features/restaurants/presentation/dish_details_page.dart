import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';
import '../../../core/widgets/food_image.dart';
import '../../../core/widgets/photo_header.dart';
import '../../cart/presentation/add_to_cart_button.dart';
import '../../cart/presentation/added_toast.dart';
import '../../cart/presentation/cart_bar.dart';
import '../../cart/presentation/cart_cubit.dart';
import '../../cart/presentation/cart_icon_button.dart';
import '../../cart/presentation/cart_problem_banner.dart';
import '../../menu/domain/dish.dart';
import '../../menu/presentation/dish_photo_hero.dart';
import '../domain/restaurant.dart';
import 'restaurant_detail_cubit.dart';
import 'restaurant_detail_state.dart';

// Dish details page (CUS-14). It gets ids only, so it loads live data
// by itself and still works after a restart.
class DishDetailsPage extends StatelessWidget {
  const DishDetailsPage({
    super.key,
    required this.restaurantId,
    required this.dishId,
  });

  final String restaurantId;
  final String dishId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RestaurantDetailCubit>(
      // The same live restaurant and menu as the restaurant page.
      create: (_) => RestaurantDetailCubit(sl(), sl())..start(restaurantId),
      child: DishDetailsView(restaurantId: restaurantId, dishId: dishId),
    );
  }
}

// The page itself. Public, so tests can give it a cubit.
class DishDetailsView extends StatelessWidget {
  const DishDetailsView({
    super.key,
    required this.restaurantId,
    required this.dishId,
  });

  final String restaurantId;
  final String dishId;

  // Makes the photo of a dish that is not available look faded.
  static const Color notAvailableFade = Color(0x99FFFFFF);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RestaurantDetailCubit, RestaurantDetailState>(
      builder: (context, state) {
        switch (state.status) {
          case RestaurantDetailStatus.loading:
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()),
            );

          case RestaurantDetailStatus.notFound:
            return _messagePage(
              icon: Icons.storefront_outlined,
              message: 'This restaurant is not available.',
            );

          case RestaurantDetailStatus.failure:
            return _messagePage(
              icon: Icons.wifi_off_rounded,
              message: state.errorMessage ?? 'Something went wrong.',
              buttonText: 'Retry',
              onPressed: () =>
                  context.read<RestaurantDetailCubit>().start(restaurantId),
            );

          case RestaurantDetailStatus.loaded:
            final dish = _findDish(state.dishes);
            // The owner deleted it while the customer was looking.
            if (dish == null) {
              return _messagePage(
                icon: Icons.restaurant_menu,
                message: 'This dish is no longer on the menu.',
              );
            }
            return _LoadedView(restaurant: state.restaurant!, dish: dish);
        }
      },
    );
  }

  Dish? _findDish(List<Dish> dishes) {
    for (final dish in dishes) {
      if (dish.id == dishId) return dish;
    }
    return null;
  }

  Widget _messagePage({
    required IconData icon,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              if (buttonText != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(onPressed: onPressed, child: Text(buttonText)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.restaurant, required this.dish});

  final Restaurant restaurant;
  final Dish dish;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canAdd = restaurant.canTakeOrders && dish.available;

    // The dish problem comes first, because it stays after opening time.
    final String? problem = !dish.available
        ? 'Not available now'
        : !restaurant.canTakeOrders
            ? 'Closed now'
            : null;

    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AddRow(
              dish: dish,
              restaurantName: restaurant.name,
              enabled: canAdd,
            ),
            const CartBar(),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          PhotoHeader(
            title: dish.name,
            height: 280,
            // The card photo grows into this one.
            photo: DishPhotoHero(
              dishId: dish.id,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FoodImage(
                    imageUrl: dish.imageUrl,
                    borderRadius: 0,
                    iconSize: 72,
                  ),
                  // A layer, not Opacity, so it stays smooth.
                  if (!dish.available)
                    const ColoredBox(color: DishDetailsView.notAvailableFade),
                ],
              ),
            ),
            trailing: (style) => CartIconButton(style: style),
          ),
          // Shows only on the restaurant that is in the cart.
          SliverToBoxAdapter(
            child: CartProblemBanner(restaurantId: restaurant.id),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (problem != null) ...[
                    _ProblemLabel(text: problem),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    dish.name,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPrice(dish.price),
                    style: textTheme.titleLarge?.copyWith(
                      color: AppTheme.brandOrange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CategoryLabel(text: dish.category),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        size: 18,
                        color: AppTheme.brandOrange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'From ${restaurant.name}',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                  if (dish.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // The full text, not cut after 2 lines like the list.
                    Text(dish.description, style: textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// The same Add button and stepper as the menu list (Option A).
class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.dish,
    required this.restaurantName,
    required this.enabled,
  });

  final Dish dish;
  final String restaurantName;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final inCart = context.select(
      (CartCubit cubit) => cubit.state.cart.quantityOf(dish.id) > 0,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                inCart && enabled ? 'In your cart' : 'Add to your order',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ),
            AddToCartButton(
              dish: dish,
              restaurantName: restaurantName,
              enabled: enabled,
              // The Add row and the cart bar are both under it here.
              toastLift: AddedToast.aboveAddRow,
            ),
          ],
        ),
      ),
    );
  }
}

// "Not available now" or "Closed now", in soft red.
class _ProblemLabel extends StatelessWidget {
  const _ProblemLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: AppTheme.dangerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cancel_rounded,
            size: 16,
            color: AppTheme.dangerRed,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.dangerRed,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.brandOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.brandOrange,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}