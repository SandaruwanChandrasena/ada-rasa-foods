import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../cart/presentation/cart_bar.dart';
import '../../cart/presentation/cart_icon_button.dart';
import '../../cart/presentation/cart_problem_banner.dart';
import '../../orders/presentation/active_order_banner.dart';
import '../../orders/presentation/my_orders_cubit.dart';
import '../../orders/presentation/my_orders_state.dart';
import 'restaurant_card.dart';
import 'restaurant_list_cubit.dart';
import 'restaurant_list_state.dart';

// Customer home: search, cuisine chips, and restaurant cards (CUS-1).
class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<RestaurantListCubit>(
          create: (_) => sl<RestaurantListCubit>()..start(),
        ),
        // Shared with My orders, so it is not closed here.
        BlocProvider<MyOrdersCubit>.value(value: sl<MyOrdersCubit>()),
      ],
      child: const _CustomerHomeView(),
    );
  }
}

class _CustomerHomeView extends StatefulWidget {
  const _CustomerHomeView();

  @override
  State<_CustomerHomeView> createState() => _CustomerHomeViewState();
}

class _CustomerHomeViewState extends State<_CustomerHomeView> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;

    // Loads this customer's orders for the banner and My orders.
    // After sign out the old watch fails, so we start it again.
    final orders = context.read<MyOrdersCubit>();
    orders.start(
      user.uid,
      force: orders.state.status == MyOrdersStatus.failure,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<RestaurantListCubit>().search('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 36),
            const SizedBox(width: 10),
            const Text(
              'Ada Rasa',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'My orders',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push(AppRoutes.myOrders),
          ),
          // Sign out moves to Profile later. The cart icon stays here.
          const CartIconButton(),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthCubit>().signOut(),
          ),
        ],
      ),
      body: BlocBuilder<RestaurantListCubit, RestaurantListState>(
        builder: (context, state) {
          return Column(
            children: [
              const ActiveOrderBanner(),
              const CartProblemBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _SearchBox(
                  controller: _searchController,
                  onChanged: context.read<RestaurantListCubit>().search,
                  onClear: _clearSearch,
                ),
              ),
              if (state.status == RestaurantListStatus.loaded &&
                  state.cuisines.isNotEmpty)
                _CuisineChips(
                  cuisines: state.cuisines,
                  selected: state.selectedCuisine,
                  onSelected: context.read<RestaurantListCubit>().selectCuisine,
                ),
              Expanded(child: _buildBody(context, state)),
            ],
          );
        },
      ),
      bottomNavigationBar: const CartBar(),
    );
  }

  Widget _buildBody(BuildContext context, RestaurantListState state) {
    switch (state.status) {
      case RestaurantListStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case RestaurantListStatus.failure:
        return _MessageView(
          icon: Icons.wifi_off_rounded,
          message: state.errorMessage ?? 'Something went wrong.',
          buttonText: 'Retry',
          onPressed: context.read<RestaurantListCubit>().start,
        );

      case RestaurantListStatus.loaded:
        final restaurants = state.visibleRestaurants;
        if (restaurants.isEmpty) {
          final noData = state.restaurants.isEmpty;
          return _MessageView(
            icon: Icons.search_off_rounded,
            message: noData
                ? 'No restaurants yet.'
                : 'No restaurants match your search.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: restaurants.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final restaurant = restaurants[index];
            return RestaurantCard(
              restaurant: restaurant,
              onTap: () =>
                  context.push(AppRoutes.restaurantPage(restaurant.id)),
            );
          },
        );
    }
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search restaurants or cuisine',
        prefixIcon: const Icon(Icons.search),
        // Rebuilds the clear button when the text changes.
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close),
                  onPressed: onClear,
                ),
        ),
        isDense: true,
      ),
    );
  }
}

class _CuisineChips extends StatelessWidget {
  const _CuisineChips({
    required this.cuisines,
    required this.selected,
    required this.onSelected,
  });

  final List<String> cuisines;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    // Null stands for the "All" chip.
    final options = <String?>[null, ...cuisines];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          return Center(
            child: ChoiceChip(
              label: Text(option ?? 'All'),
              selected: option == selected,
              showCheckmark: false,
              onSelected: (_) => onSelected(option),
            ),
          );
        },
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