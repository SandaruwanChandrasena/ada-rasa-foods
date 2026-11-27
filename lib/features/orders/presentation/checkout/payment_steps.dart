import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../payments/presentation/pay/payment_state.dart';
import 'checkout_state.dart';

// The 3 steps on the card payment screen, in order.
const paymentStepNames = ['Checking card', 'Paying', 'Saving order'];

// The running step. Steps before it are done; 3 means all are done.
// [cardChecked] turns true a moment after the demo payment starts.
int paymentStepOf(
  PaymentState payment,
  CheckoutState checkout, {
  required bool cardChecked,
}) {
  switch (payment.status) {
    case DemoPaymentStatus.idle:
    case DemoPaymentStatus.declined:
      return 0;
    case DemoPaymentStatus.processing:
      return cardChecked ? 1 : 0;
    case DemoPaymentStatus.approved:
      // "Saving order" runs until the order is really saved.
      return checkout.status == CheckoutStatus.placed ? 3 : 2;
  }
}

enum _StepState { done, running, waiting }

// The step list: green tick, orange spinner, or grey circle.
class PaymentSteps extends StatelessWidget {
  const PaymentSteps({super.key, required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paymentStepNames.length; i++)
          _StepRow(
            key: ValueKey('payment_step_$i'),
            name: paymentStepNames[i],
            state: i < current
                ? _StepState.done
                : i == current
                    ? _StepState.running
                    : _StepState.waiting,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({super.key, required this.name, required this.state});

  final String name;
  final _StepState state;

  String get _spoken => switch (state) {
        _StepState.done => '$name, done',
        _StepState.running => '$name, now',
        _StepState.waiting => '$name, waiting',
      };

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final color = switch (state) {
      _StepState.done => AppTheme.successGreen,
      _StepState.running => AppTheme.deepOrange,
      _StepState.waiting => AppTheme.textMuted,
    };

    return Semantics(
      container: true,
      label: _spoken,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(state),
                    child: _icon(reduceMotion),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: state == _StepState.running
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon(bool reduceMotion) {
    switch (state) {
      case _StepState.done:
        return const Icon(
          Icons.check_circle_rounded,
          color: AppTheme.successGreen,
          size: 24,
        );
      case _StepState.running:
        // A still dot when animations are off.
        if (reduceMotion) {
          return const Icon(
            Icons.radio_button_checked_rounded,
            color: AppTheme.brandOrange,
            size: 24,
          );
        }
        return const Padding(
          padding: EdgeInsets.all(3),
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppTheme.brandOrange,
          ),
        );
      case _StepState.waiting:
        return const Icon(
          Icons.radio_button_unchecked_rounded,
          color: AppTheme.border,
          size: 24,
        );
    }
  }
}