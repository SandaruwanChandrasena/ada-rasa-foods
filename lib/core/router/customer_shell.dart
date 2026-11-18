import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/orders/presentation/my_orders_cubit.dart';
import '../../features/orders/presentation/my_orders_state.dart';
import '../widgets/customer_bottom_bar.dart';
import 'tab_scroll.dart';

// The frame around the customer's Home, Orders and Profile tabs.
class CustomerShell extends StatefulWidget {
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
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  final _reselect = TabReselectSignal();

  void _onTap(int index) {
    // Tapping the open tab scrolls its page to the top.
    if (index == widget.currentIndex) {
      _reselect.reselect(index);
    } else {
      widget.onTabSelected(index);
    }
  }

  @override
  void dispose() {
    _reselect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onHome = widget.currentIndex == CustomerBottomBar.home;

    return PopScope(
      // The phone back button goes to Home first, then closes the app.
      canPop: onHome,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onTabSelected(CustomerBottomBar.home);
      },
      child: TabReselectScope(
        signal: _reselect,
        child: Scaffold(
          // Each tab page moves itself up for the keyboard.
          resizeToAvoidBottomInset: false,
          body: widget.child,
          bottomNavigationBar:
              BlocSelector<MyOrdersCubit, MyOrdersState, bool>(
            selector: (state) => state.activeOrders.isNotEmpty,
            builder: (context, hasActiveOrder) => CustomerBottomBar(
              currentIndex: widget.currentIndex,
              onTap: _onTap,
              showOrdersDot: hasActiveOrder,
            ),
          ),
        ),
      ),
    );
  }
}