import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/orders/presentation/my_orders_cubit.dart';
import '../../features/orders/presentation/my_orders_state.dart';
import '../widgets/customer_bottom_bar.dart';

// The frame around the customer's Home, Orders and Profile tabs.
class CustomerShell extends StatelessWidget {
  const CustomerShell({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  // The open tab's page.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onHome = currentIndex == CustomerBottomBar.home;

    return PopScope(
      // The phone back button goes to Home first, then closes the app.
      canPop: onHome,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onTabSelected(CustomerBottomBar.home);
      },
      child: Scaffold(
        // Each tab page moves itself up for the keyboard.
        resizeToAvoidBottomInset: false,
        body: child,
        bottomNavigationBar: BlocSelector<MyOrdersCubit, MyOrdersState, bool>(
          selector: (state) => state.activeOrders.isNotEmpty,
          builder: (context, hasActiveOrder) => CustomerBottomBar(
            currentIndex: currentIndex,
            onTap: onTabSelected,
            showOrdersDot: hasActiveOrder,
          ),
        ),
      ),
    );
  }
}