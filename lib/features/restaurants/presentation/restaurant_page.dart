import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/widgets/food_image.dart';
import '../../cart/presentation/add_to_cart_button.dart';
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            title: Text(restaurant.name),
            flexibleSpace: FlexibleSpaceBar(
              background: FoodImage(
                imageUrl: restaurant.imageUrl,
                borderRadius: 0,
                iconSize: 72,
              ),
            ),
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

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final grey = Colors.grey.shade600;

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
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _OpenLabel(isOpen: restaurant.isOpen),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            restaurant.cuisine,
            style: textTheme.bodyMedium?.copyWith(color: grey),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  restaurant.address,
                  style: textTheme.bodySmall?.copyWith(color: grey),
                ),
              ),
            ],
          ),
          if (!restaurant.isOpen) ...[
            const SizedBox(height: 12),
            Text(
              'This restaurant is closed now. You can see the menu, '
              'but you cannot add food to the cart.',
              style: textTheme.bodySmall?.copyWith(color: grey),
            ),
          ],
          const Divider(height: 28),
        ],
      ),
    );
  }
}

class _OpenLabel extends StatelessWidget {
  const _OpenLabel({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.shade600 : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOpen ? 'Open' : 'Closed',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
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