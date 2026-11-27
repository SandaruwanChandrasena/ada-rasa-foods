import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/order_status.dart';
import 'order_details_cards.dart';
import 'order_status_cubit.dart';
import 'order_status_header.dart';
import 'order_status_state.dart';

// One order, live: status steps, pickup address, payment, cancel (CUS-11).
class OrderStatusScreen extends StatelessWidget {
  const OrderStatusScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OrderStatusCubit>(
      create: (_) => OrderStatusCubit(sl())..start(orderId),
      child: const _OrderStatusView(),
    );
  }
}

class _OrderStatusView extends StatelessWidget {
  const _OrderStatusView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OrderStatusCubit, OrderStatusState>(
      listenWhen: (previous, current) => previous.noticeId != current.noticeId,
      listener: (context, state) {
        final notice = state.notice;
        if (notice == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(notice),
              duration: const Duration(seconds: 5),
            ),
          );
      },
      builder: (context, state) {
        final order = state.order;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              order == null ? 'Your order' : 'Order #${order.shortNumber}',
            ),
          ),
          body: switch (state.view) {
            OrderView.loading =>
              const Center(child: CircularProgressIndicator()),
            OrderView.failure => _MessageView(
                message: state.errorMessage ?? 'Something went wrong.',
                buttonText: 'Retry',
                onPressed: () => context.read<OrderStatusCubit>().retry(),
              ),
            OrderView.notFound => _MessageView(
                message: 'This order was not found.',
                buttonText: 'Go to home',
                onPressed: () => context.go(AppRoutes.customer),
              ),
            OrderView.loaded => _OrderDetails(state: state),
          },
        );
      },
    );
  }
}

class _OrderDetails extends StatelessWidget {
  const _OrderDetails({required this.state});

  final OrderStatusState state;

  @override
  Widget build(BuildContext context) {
    final order = state.order!;
    final stopped = order.status == OrderStatus.rejected ||
        order.status == OrderStatus.cancelled;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        OrderStatusCard(order: order),
        const SizedBox(height: 12),
        if (!stopped) ...[
          OrderStatusSteps(
            current: order.status,
            updatedAt: order.updatedAt,
          ),
          const SizedBox(height: 12),
        ],
        if (order.status == OrderStatus.ready) ...[
          OrderPickupAtCard(order: order),
          const SizedBox(height: 12),
        ],
        OrderPickupFromCard(order: order),
        const SizedBox(height: 12),
        OrderItemsCard(order: order),
        const SizedBox(height: 12),
        OrderPaymentCard(order: order),
        if (state.canCancel || state.isCancelling) ...[
          const SizedBox(height: 20),
          OrderCancelButton(
            isCancelling: state.isCancelling,
            onCancel: () => context.read<OrderStatusCubit>().cancel(),
          ),
        ],
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  final String message;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }
}