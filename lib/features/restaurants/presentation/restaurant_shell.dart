import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../menu/domain/dish.dart';
import '../../menu/presentation/dish_form_screen.dart';
import '../../menu/presentation/menu_manage_cubit.dart';
import '../../menu/presentation/menu_manage_screen.dart';
import '../../orders/presentation/restaurant_orders_screen.dart';

// Opens the Add or Edit dish page.
void openDishPage(BuildContext context, DishFormArgs args) {
  context.push(AppRoutes.dishForm, extra: args);
}

// The owner's two tabs: Orders and Menu, with a bottom bar.
// Both tabs stay alive, so new order alerts work on the Menu tab too.
class RestaurantShell extends StatefulWidget {
  const RestaurantShell({
    super.key,
    this.callPhone = openDialer,
    this.openDish = openDishPage,
  });

  // Tests give fakes, so no real phone app or page opens.
  final Future<bool> Function(String phone) callPhone;
  final void Function(BuildContext context, DishFormArgs args) openDish;

  @override
  State<RestaurantShell> createState() => _RestaurantShellState();
}

class _RestaurantShellState extends State<RestaurantShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          RestaurantOrdersView(callPhone: widget.callPhone),
          _MenuPage(openDish: widget.openDish),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Menu',
          ),
        ],
      ),
    );
  }
}

class _MenuPage extends StatelessWidget {
  const _MenuPage({required this.openDish});

  final void Function(BuildContext context, DishFormArgs args) openDish;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthCubit>().signOut(),
          ),
        ],
      ),
      body: MenuManageView(
        onAdd: () => _open(context),
        onEdit: (dish) => _open(context, dish: dish),
      ),
    );
  }

  void _open(BuildContext context, {Dish? dish}) {
    final restaurantId =
        context.read<AuthCubit>().state.user?.restaurantId ?? '';
    final categories = context.read<MenuManageCubit>().state.categories;

    openDish(
      context,
      DishFormArgs(
        restaurantId: restaurantId,
        categories: categories,
        dish: dish,
      ),
    );
  }
}