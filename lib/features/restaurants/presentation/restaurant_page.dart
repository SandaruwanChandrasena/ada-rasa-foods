import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/food_image.dart';
import '../../../core/widgets/open_status_chip.dart';
import '../../../core/widgets/photo_header.dart';
import '../../cart/presentation/add_to_cart_button.dart';
import '../../cart/presentation/cart_bar.dart';
import '../../cart/presentation/cart_icon_button.dart';
import '../../cart/presentation/cart_problem_banner.dart';
import '../../menu/presentation/dish_row.dart';
import '../domain/restaurant.dart';
import 'restaurant_detail_cubit.dart';
import 'restaurant_detail_state.dart';

// Restaurant page: photo, details, and menu by category (CUS-2).
class RestaurantPage extends StatelessWidget {
  const RestaurantPage({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RestaurantDetailCubit>(
      // get_it finds the restaurant and menu repositories by type.
      create: (_) => RestaurantDetailCubit(sl(), sl())..start(restaurantId),
      child: _RestaurantView(restaurantId: restaurantId),
    );
  }
}

class _RestaurantView extends StatelessWidget {
  const _RestaurantView({required this.restaurantId});

  final String restaurantId;

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
            return Scaffold(
              appBar: AppBar(),
              body: const _MessageView(
                icon: Icons.storefront_outlined,
                message: 'This restaurant is not available.',
              ),
            );

          case RestaurantDetailStatus.failure:
            return Scaffold(
              appBar: AppBar(),
              body: _MessageView(
                icon: Icons.wifi_off_rounded,
                message: state.errorMessage ?? 'Something went wrong.',
                buttonText: 'Retry',
                onPressed: () =>
                    context.read<RestaurantDetailCubit>().start(restaurantId),
              ),
            );

          case RestaurantDetailStatus.loaded:
            return _LoadedView(state: state);
        }
      },
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state});

  final RestaurantDetailState state;

  @override
  Widget build(BuildContext context) {
    final restaurant = state.restaurant!;
    final sections = state.menuSections;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      bottomNavigationBar: const CartBar(),
      body: CustomScrollView(
        slivers: [
          PhotoHeader(
            title: restaurant.name,
            photo: FoodImage(
              imageUrl: restaurant.imageUrl,
              borderRadius: 0,
              iconSize: 72,
            ),
            trailing: (style) => CartIconButton(style: style),
          ),
          // Shows only on the restaurant that is in the cart.
          SliverToBoxAdapter(
            child: CartProblemBanner(restaurantId: restaurant.id),
          ),
          SliverToBoxAdapter(child: _InfoSection(restaurant: restaurant)),
          if (sections.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No dishes yet.')),
              ),
            ),
          for (final entry in sections.entries) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Text(
                  entry.key,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverList.list(
              children: [
                for (final dish in entry.value)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DishRow(
                      dish: dish,
                      onTap: () => context.push(
                        AppRoutes.dishDetails(restaurant.id, dish.id),
                      ),
                      trailing: AddToCartButton(
                        dish: dish,
                        restaurantName: restaurant.name,
                        enabled: restaurant.canTakeOrders && dish.available,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.restaurant});

  static const closedText = 'Closed now. You can still see the menu.';

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final open = restaurant.canTakeOrders;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  restaurant.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OpenStatusChip(isOpen: open),
            ],
          ),
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.restaurant_menu_rounded,
            text: restaurant.cuisine,
          ),
          const SizedBox(height: 6),
          _InfoLine(
            icon: Icons.location_on_rounded,
            text: restaurant.address,
          ),
          if (!open) ...[
            const SizedBox(height: 12),
            Text(
              closedText,
              style: const TextStyle(
                color: AppTheme.dangerRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Divider(height: 28),
        ],
      ),
    );
  }
}

// An orange icon with grey text, like on the Home cards.
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.brandOrange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: AppTheme.textMuted)),
        ),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.message,
    this.buttonText,
    this.onPressed,
  });

  final IconData icon;
  final String message;
  final String? buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              OutlinedButton(onPressed: onPressed, child: Text(buttonText!)),
            ],
          ],
        ),
      ),
    );
  }
}