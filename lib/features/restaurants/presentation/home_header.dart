import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../orders/presentation/my_orders_cubit.dart';
import '../../orders/presentation/my_orders_state.dart';

// "Hi, Nimal" with a small orange wave, for the Home top bar.
class HomeGreeting extends StatelessWidget {
  const HomeGreeting({super.key});

  // The first word of the name, or "there" when there is no name.
  static String firstName(String name) {
    final first = name.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'there' : first;
  }

  @override
  Widget build(BuildContext context) {
    final name = context.select<AuthCubit, String>(
      (cubit) => cubit.state.user?.name ?? '',
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.waving_hand_rounded, color: AppTheme.brandOrange),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Hi, ${firstName(name)}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// The orange welcome card at the top of the restaurant list.
class WelcomeBanner extends StatelessWidget {
  const WelcomeBanner({super.key});

  static const title = "Today's taste";
  static const subtitle = 'Ready for pickup';

  // Hidden while an order banner shows, so Home has one big banner only.
  static bool shownFor(MyOrdersState state) {
    switch (state.status) {
      case MyOrdersStatus.loading:
        return false;
      case MyOrdersStatus.failure:
        return true;
      case MyOrdersStatus.loaded:
        return state.unseenRejected == null && state.activeOrders.isEmpty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = context.select<MyOrdersCubit, bool>(
      (cubit) => shownFor(cubit.state),
    );
    if (!show) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        decoration: BoxDecoration(
          color: AppTheme.brandOrange,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.takeout_dining_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }
}