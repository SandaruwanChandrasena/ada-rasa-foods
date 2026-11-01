import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../cart/presentation/cart_bar.dart';
import '../../cart/presentation/cart_icon_button.dart';
import '../../cart/presentation/cart_problem_banner.dart';
import '../../orders/presentation/active_order_banner.dart';
import '../../orders/presentation/my_orders_cubit.dart';
import '../../orders/presentation/my_orders_state.dart';
import 'home_restaurant_list.dart';
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
          final cubit = context.read<RestaurantListCubit>();
          return Column(
            children: [
              // Banners fade in and the search box slides down, once.
              const FadeSlideIn(
                offset: Offset.zero,
                duration: Duration(milliseconds: 400),
                child: ActiveOrderBanner(),
              ),
              const FadeSlideIn(
                offset: Offset.zero,
                duration: Duration(milliseconds: 400),
                child: CartProblemBanner(),
              ),
              FadeSlideIn(
                offset: const Offset(0, -12),
                duration: const Duration(milliseconds: 450),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _SearchBox(
                    controller: _searchController,
                    onChanged: cubit.search,
                    onClear: _clearSearch,
                  ),
                ),
              ),
              Expanded(
                child: HomeRestaurantList(
                  state: state,
                  onCuisineSelected: cubit.selectCuisine,
                  onRetry: cubit.start,
                  onOpen: (restaurant) =>
                      context.push(AppRoutes.restaurantPage(restaurant.id)),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const CartBar(),
    );
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