import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/presentation/auth_cubit.dart';
import '../../menu/presentation/menu_manage_screen.dart';
import '../../orders/presentation/restaurant_orders_screen.dart';

// The owner's two tabs: Orders and Menu, with a bottom bar.
// Both tabs stay alive, so new order alerts work on the Menu tab too.
class RestaurantShell extends StatefulWidget {
  const RestaurantShell({super.key, this.callPhone = openDialer});

  // Tests give a fake, so no real phone app opens.
  final Future<bool> Function(String phone) callPhone;

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
          const _MenuPage(),
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
  const _MenuPage();

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
      // The Add and Edit dish pages come in the next part.
      body: MenuManageView(
        onAdd: () => _comingSoon(context),
        onEdit: (_) => _comingSoon(context),
      ),
    );
  }

  static void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('The dish page comes next.')),
      );
  }
}