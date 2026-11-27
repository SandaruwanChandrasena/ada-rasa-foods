import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import 'my_orders_cubit.dart';
import 'my_orders_list.dart';
import 'my_orders_state.dart';

// My orders: newest first, live. Tap one to see its status.
class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The same cubit as the home banner, so both stay in step.
    return BlocProvider<MyOrdersCubit>.value(
      value: sl<MyOrdersCubit>(),
      child: Scaffold(
        appBar: AppBar(title: const Text('My orders')),
        body: BlocBuilder<MyOrdersCubit, MyOrdersState>(
          builder: (context, state) => MyOrdersList(
            state: state,
            onOpen: (order) {
              context.read<MyOrdersCubit>().markSeen(order);
              context.push(AppRoutes.orderStatus(order.id));
            },
            onRetry: () => context.read<MyOrdersCubit>().retry(),
            onBrowse: () => context.go(AppRoutes.customer),
          ),
        ),
      ),
    );
  }
}