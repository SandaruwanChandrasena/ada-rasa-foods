import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../menu/presentation/menu_manage_cubit.dart';
import '../../restaurants/presentation/my_restaurant_cubit.dart';
import '../../restaurants/presentation/restaurant_photo_cubit.dart';
import '../../restaurants/presentation/restaurant_shell.dart';
import '../domain/food_order.dart';
import 'restaurant_order_card.dart';
import 'restaurant_orders_cubit.dart';
import 'restaurant_orders_state.dart';

// The restaurant owner's home. Makes the cubits, then shows the
// Orders and Menu tabs (RES-1 to RES-5).
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

    return MultiBlocProvider(
      key: ValueKey(restaurantId),
      providers: [
        BlocProvider<RestaurantOrdersCubit>(
          create: (_) => sl<RestaurantOrdersCubit>()..start(restaurantId),
        ),
        BlocProvider<MyRestaurantCubit>(
          create: (_) => sl<MyRestaurantCubit>()..start(restaurantId),
        ),
        BlocProvider<RestaurantPhotoCubit>(
          create: (_) => RestaurantPhotoCubit(
            sl(),
            uploader: sl(),
            picker: sl(),
            restaurantId: restaurantId,
          ),
        ),
        BlocProvider<MenuManageCubit>(
          create: (_) => sl<MenuManageCubit>()..start(restaurantId),
        ),
      ],
      child: const RestaurantShell(),
    );
  }
}

// Opens the phone app. Gives false if it could not open.
Future<bool> openDialer(String phone) async {
  try {
    return await launchUrl(Uri(scheme: 'tel', path: phone));
  } catch (_) {
    return false;
  }
}

// The board itself. Public, so tests can give it mock cubits.
class RestaurantOrdersView extends StatelessWidget {
  const RestaurantOrdersView({super.key, this.callPhone = openDialer});

  // Tests give a fake, so no real phone app opens.
  final Future<bool> Function(String phone) callPhone;

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
          BlocListener<MyRestaurantCubit, MyRestaurantState>(
            listenWhen: (previous, current) =>
                previous.noticeId != current.noticeId,
            listener: (context, state) =>
                _showMessage(context, state.notice),
          ),
        ],
        child: Scaffold(
          appBar: AppBar(
            title: const _RestaurantName(),
            actions: [
              const _OpenSwitch(),
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
          body: Column(
            children: [
              const _ClosedBanner(),
              Expanded(child: _board()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _board() {
    return BlocBuilder<RestaurantOrdersCubit, RestaurantOrdersState>(
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
                  callPhone: callPhone,
                ),
                _OrderList(
                  orders: state.activeOrders,
                  emptyText: 'No active orders.',
                  callPhone: callPhone,
                ),
                state.doneLoaded
                    ? _OrderList(
                        orders: state.done,
                        emptyText: 'No finished orders yet.',
                        callPhone: callPhone,
                      )
                    : const Center(
                        child: CircularProgressIndicator(),
                      ),
              ],
            );
        }
      },
    );
  }

  static void _showMessage(BuildContext context, String? message) {
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

// The restaurant name, or "Orders" until it loads.
class _RestaurantName extends StatelessWidget {
  const _RestaurantName();

  @override
  Widget build(BuildContext context) {
    final name = context.select(
      (MyRestaurantCubit cubit) => cubit.state.restaurant?.name,
    );
    return Text(
      name == null || name.isEmpty ? 'Orders' : name,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// "Open" or "Closed" with a switch (RES-4). Hidden until it loads.
class _OpenSwitch extends StatelessWidget {
  const _OpenSwitch();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MyRestaurantCubit>().state;
    final restaurant = state.restaurant;
    if (state.view != MyRestaurantView.loaded || restaurant == null) {
      return const SizedBox.shrink();
    }

    final open = restaurant.isOpen;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          open ? 'Open' : 'Closed',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: open ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
        Switch(
          value: open,
          onChanged: state.canSwitch
              ? (value) => context.read<MyRestaurantCubit>().setOpen(value)
              : null,
        ),
      ],
    );
  }
}

// A red strip while closed, so the owner knows why no orders come.
class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner();

  @override
  Widget build(BuildContext context) {
    final closed = context.select(
      (MyRestaurantCubit cubit) => cubit.state.restaurant?.isOpen == false,
    );
    if (!closed) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.red.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        'Closed. Customers cannot order now.',
        style: TextStyle(color: Colors.red.shade700),
      ),
    );
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
  const _OrderList({
    required this.orders,
    required this.emptyText,
    required this.callPhone,
  });

  final List<FoodOrder> orders;
  final String emptyText;
  final Future<bool> Function(String phone) callPhone;

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
            onCall: (phone) => _call(context, phone),
          ),
        );
      },
    );
  }

  Future<void> _call(BuildContext context, String phone) async {
    final opened = await callPhone(phone);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Could not open the phone app.')),
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