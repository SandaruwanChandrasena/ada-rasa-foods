import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/owner_bottom_bar.dart';
import '../../../auth/presentation/auth_cubit.dart';
import '../../../dashboard/presentation/owner_dashboard_page.dart';
import '../../../menu/domain/dish.dart';
import '../../../menu/presentation/dish_form_screen.dart';
import '../../../menu/presentation/menu_manage_cubit.dart';
import '../../../menu/presentation/menu_manage_screen.dart';
import '../../../orders/presentation/board/restaurant_orders_cubit.dart';
import '../../../orders/presentation/board/restaurant_orders_screen.dart';
import 'owner_profile_page.dart';

// Opens the Add or Edit dish page.
void openDishPage(BuildContext context, DishFormArgs args) {
  context.push(AppRoutes.dishForm, extra: args);
}

// The owner's four tabs: Home, Orders, Menu and Profile.
// All tabs stay alive, so new order alerts work on every tab.
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
  int _index = OwnerBottomBar.home;

  // The Home cards use it to open the board on a chip.
  final _chipRequest = BoardChipRequest();

  void _openBoard(int chip) {
    _chipRequest.open(chip);
    setState(() => _index = OwnerBottomBar.orders);
  }

  @override
  void dispose() {
    _chipRequest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasNewOrder = context.select(
      (RestaurantOrdersCubit cubit) => cubit.state.newOrders.isNotEmpty,
    );

    return PopScope(
      // The phone back button goes to Home first, then closes the app.
      canPop: _index == OwnerBottomBar.home,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _index = OwnerBottomBar.home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            OwnerDashboardView(onOpenBoard: _openBoard),
            RestaurantOrdersView(
              callPhone: widget.callPhone,
              chipRequest: _chipRequest,
            ),
            _MenuPage(openDish: widget.openDish),
            const OwnerProfilePage(),
          ],
        ),
        bottomNavigationBar: OwnerBottomBar(
          currentIndex: _index,
          onTap: (index) => setState(() => _index = index),
          showOrdersDot: hasNewOrder,
        ),
      ),
    );
  }
}

class _MenuPage extends StatelessWidget {
  const _MenuPage({required this.openDish});

  final void Function(BuildContext context, DishFormArgs args) openDish;

  @override
  Widget build(BuildContext context) {
    // MenuManageView has its own top bar with the Add dish pill.
    return MenuManageView(
      onAdd: () => _open(context),
      onEdit: (dish) => _open(context, dish: dish),
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