import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

// The restaurant owner's bottom bar: Orders, Menu, Profile.
class OwnerBottomBar extends StatelessWidget {
  const OwnerBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showOrdersDot = false,
  });

  static const int orders = 0;
  static const int menu = 1;
  static const int profile = 2;

  final int currentIndex;
  final ValueChanged<int> onTap;

  // True while a new order waits for Accept or Reject.
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
          NavigationDestination(
            icon: Badge(
              isLabelVisible: showOrdersDot,
              smallSize: 9,
              backgroundColor: AppTheme.brandOrange,
              child: const Icon(Icons.receipt_long_rounded),
            ),
            label: 'Orders',
            tooltip: showOrdersDot ? 'Orders, new orders waiting' : 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.restaurant_menu_rounded),
            label: 'Menu',
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