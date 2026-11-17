import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

// The customer's bottom bar: Home, Orders, Profile.
class CustomerBottomBar extends StatelessWidget {
  const CustomerBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showOrdersDot = false,
  });

  static const int home = 0;
  static const int orders = 1;
  static const int profile = 2;

  final int currentIndex;

  // Also called when the tab is already open, so the page can scroll up.
  final ValueChanged<int> onTap;

  // True while an order is still going.
  final bool showOrdersDot;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: showOrdersDot,
              smallSize: 9,
              backgroundColor: AppTheme.brandOrange,
              child: const Icon(Icons.receipt_long_rounded),
            ),
            label: 'Orders',
            tooltip: showOrdersDot ? 'Orders, one is still going' : 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}