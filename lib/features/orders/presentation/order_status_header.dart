import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/food_order.dart';
import '../domain/order_status.dart';

enum _Tone { going, good, bad }

_Tone _toneOf(OrderStatus status) => switch (status) {
      OrderStatus.ready ||
      OrderStatus.completed ||
      OrderStatus.delivered =>
        _Tone.good,
      OrderStatus.rejected || OrderStatus.cancelled => _Tone.bad,
      _ => _Tone.going,
    };

// The coloured card at the top: round icon, status, short message.
class OrderStatusCard extends StatelessWidget {
  const OrderStatusCard({super.key, required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 300);
    final name = order.restaurantName;

    final (Color strong, Color soft) = switch (_toneOf(order.status)) {
      _Tone.going => (AppTheme.brandOrange, AppTheme.softOrange),
      _Tone.good => (AppTheme.successGreen, AppTheme.successBg),
      _Tone.bad => (AppTheme.dangerRed, AppTheme.dangerBg),
    };
    final textColor =
        strong == AppTheme.brandOrange ? AppTheme.deepOrange : strong;

    final (IconData icon, String message) = switch (order.status) {
      OrderStatus.placed => (Icons.schedule_rounded, 'Waiting for $name'),
      OrderStatus.accepted => (Icons.thumb_up_rounded, '$name accepted it'),
      OrderStatus.preparing => (
          Icons.soup_kitchen_rounded,
          'Your food is cooking',
        ),
      OrderStatus.ready => (Icons.shopping_bag_rounded, 'Please collect it'),
      OrderStatus.completed => (Icons.done_all_rounded, 'Enjoy your meal!'),
      OrderStatus.rejected => (
          Icons.close_rounded,
          '$name could not take it',
        ),
      OrderStatus.cancelled => (
          Icons.close_rounded,
          'You cancelled this order',
        ),
      // Stage 2 (delivery) statuses.
      _ => (Icons.delivery_dining_rounded, order.statusLabel),
    };

    return AnimatedContainer(
      duration: duration,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: duration,
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: strong, shape: BoxShape.circle),
            child: AnimatedSwitcher(
              duration: duration,
              child: Icon(
                icon,
                key: ValueKey(icon),
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Read out by screen readers when the status changes.
                Semantics(
                  liveRegion: true,
                  child: Text(
                    order.statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Placed, Accepted, Preparing, Ready for pickup, Completed.
// Only the latest step has a time, as only updatedAt is saved.
class OrderStatusSteps extends StatelessWidget {
  const OrderStatusSteps({
    super.key,
    required this.current,
    this.updatedAt,
  });

  final OrderStatus current;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    const steps = OrderStatus.pickupSteps;
    final currentIndex = steps.indexOf(current);
    final allDone = current == OrderStatus.completed;
    final time = updatedAt == null
        ? null
        : TimeOfDay.fromDateTime(updatedAt!).format(context);

    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final done = i < currentIndex || allDone;
      if (i > 0) {
        // The line between 2 steps is green once both are reached.
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(
              width: 2,
              height: 12,
              color: i <= currentIndex
                  ? AppTheme.successGreen
                  : AppTheme.border,
            ),
          ),
        );
      }
      children.add(
        _StepRow(
          key: ValueKey('order_step_$i'),
          label: steps[i].labelFor(Fulfillment.pickup),
          state: done
              ? _StepState.done
              : i == currentIndex
                  ? _StepState.now
                  : _StepState.waiting,
          time: i == currentIndex ? time : null,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

enum _StepState { done, now, waiting }

class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.label,
    required this.state,
    required this.time,
  });

  final String label;
  final _StepState state;
  final String? time;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (state) {
      _StepState.done => (Icons.check_circle_rounded, AppTheme.successGreen),
      _StepState.now => (
          Icons.radio_button_checked_rounded,
          AppTheme.brandOrange,
        ),
      _StepState.waiting => (
          Icons.radio_button_unchecked_rounded,
          AppTheme.textMuted,
        ),
    };
    final spoken = switch (state) {
      _StepState.done => '$label, done',
      _StepState.now => '$label, now',
      _StepState.waiting => '$label, waiting',
    };

    return Semantics(
      container: true,
      label: spoken,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: switch (state) {
                    _StepState.done => AppTheme.textDark,
                    _StepState.now => AppTheme.deepOrange,
                    _StepState.waiting => AppTheme.textMuted,
                  },
                  fontWeight: state == _StepState.now
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ),
            if (time != null) ...[
              const SizedBox(width: 8),
              Text(
                time!,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}