import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../domain/food_order.dart';
import 'restaurant_order_card.dart';
import 'restaurant_orders_cubit.dart';
import 'restaurant_orders_state.dart';

// The restaurant owner's home: the live orders board (RES-1, RES-2).
class RestaurantOrdersScreen extends StatelessWidget {
  const RestaurantOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final restaurantId =
        context.select((AuthCubit cubit) => cubit.state.user?.restaurantId);

    // The admin links a restaurant to the owner (ADM-5).
    if (restaurantId == null || restaurantId.isEmpty) {
      return const _NoRestaurantView();
    }

    return BlocProvider<RestaurantOrdersCubit>(
      key: ValueKey(restaurantId),
      create: (_) => sl<RestaurantOrdersCubit>()..start(restaurantId),
      child: const RestaurantOrdersView(),
    );
  }
}

// The board itself. Public, so tests can give it a mock cubit.
class RestaurantOrdersView extends StatelessWidget {
  const RestaurantOrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: MultiBlocListener(
        listeners: [
          BlocListener<RestaurantOrdersCubit, RestaurantOrdersState>(
            listenWhen: (previous, current) =>
                previous.noticeId != current.noticeId,
            listener: (context, state) =>
                _showMessage(context, state.notice),
          ),
          BlocListener<RestaurantOrdersCubit, RestaurantOrdersState>(
            listenWhen: (previous, current) =>
                previous.newOrderAlertId != current.newOrderAlertId,
            listener: (context, state) {
              HapticFeedback.heavyImpact();
              _showMessage(context, 'New order #${state.newOrderNumber}');
            },
          ),
        ],
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Orders'),
            actions: [
              IconButton(
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout),
                onPressed: () => context.read<AuthCubit>().signOut(),
              ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(kTextTabBarHeight),
              child: _BoardTabs(),
            ),
          ),
          body: BlocBuilder<RestaurantOrdersCubit, RestaurantOrdersState>(
            builder: (context, state) {
              switch (state.view) {
                case BoardView.loading:
                  return const Center(child: CircularProgressIndicator());
                case BoardView.failure:
                  return _MessageView(
                    icon: Icons.wifi_off_rounded,
                    message: state.errorMessage ?? 'Something went wrong.',
                    buttonText: 'Retry',
                    onPressed: () =>
                        context.read<RestaurantOrdersCubit>().retry(),
                  );
                case BoardView.loaded:
                  return TabBarView(
                    children: [
                      _OrderList(
                        orders: state.newOrders,
                        emptyText: 'No new orders.',
                      ),
                      _OrderList(
                        orders: state.activeOrders,
                        emptyText: 'No active orders.',
                      ),
                      state.doneLoaded
                          ? _OrderList(
                              orders: state.done,
                              emptyText: 'No finished orders yet.',
                            )
                          : const Center(
                              child: CircularProgressIndicator(),
                            ),
                    ],
                  );
              }
            },
          ),
        ),
      ),
    );
  }

  static void _showMessage(BuildContext context, String? message) {
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

// "New (2)" and "Active (1)". Done has no count.
class _BoardTabs extends StatelessWidget {
  const _BoardTabs();

  @override
  Widget build(BuildContext context) {
    final counts = context.select(
      (RestaurantOrdersCubit cubit) => (
        cubit.state.newOrders.length,
        cubit.state.activeOrders.length,
      ),
    );

    return TabBar(
      tabs: [
        Tab(text: counts.$1 == 0 ? 'New' : 'New (${counts.$1})'),
        Tab(text: counts.$2 == 0 ? 'Active' : 'Active (${counts.$2})'),
        const Tab(text: 'Done'),
      ],
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, required this.emptyText});

  final List<FoodOrder> orders;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    final busyIds = context.select(
      (RestaurantOrdersCubit cubit) => cubit.state.busyIds,
    );

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        // A new card fades in. The key keeps it from playing again.
        return FadeSlideIn(
          key: ValueKey(order.id),
          child: RestaurantOrderCard(
            order: order,
            busy: busyIds.contains(order.id),
            onMove: (next) =>
                context.read<RestaurantOrdersCubit>().move(order, next),
          ),
        );
      },
    );
  }
}

class _NoRestaurantView extends StatelessWidget {
  const _NoRestaurantView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthCubit>().signOut(),
          ),
        ],
      ),
      body: const _MessageView(
        icon: Icons.storefront_outlined,
        message: 'No restaurant is linked to your account. '
            'Ask the admin.',
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
    final text = buttonText;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (text != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onPressed, child: Text(text)),
            ],
          ],
        ),
      ),
    );
  }
}