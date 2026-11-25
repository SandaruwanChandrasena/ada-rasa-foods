import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';
import '../../payments/domain/payment_card.dart';
import '../../payments/presentation/card_art.dart';
import '../../payments/presentation/enter_animation.dart';
import '../../payments/presentation/payment_state.dart';
import 'checkout_state.dart';
import 'payment_steps.dart';

// The steps of a card payment that cover the checkout (CUS-10).
enum CardPaymentStage { processing, success, declined, failed }

// Which step to show. Null means no cover (cash, or nothing started).
CardPaymentStage? cardPaymentStageOf(
  PaymentState payment,
  CheckoutState checkout,
) {
  switch (payment.status) {
    case DemoPaymentStatus.idle:
      return null;
    case DemoPaymentStatus.processing:
      return CardPaymentStage.processing;
    case DemoPaymentStatus.declined:
      return CardPaymentStage.declined;
    case DemoPaymentStatus.approved:
      // "Successful" shows only after the order is really saved.
      return switch (checkout.status) {
        CheckoutStatus.placed => CardPaymentStage.success,
        CheckoutStatus.failure => CardPaymentStage.failed,
        _ => CardPaymentStage.processing,
      };
  }
}

// Full screen: Processing, Payment successful, or a failed payment.
class CheckoutPaymentView extends StatefulWidget {
  const CheckoutPaymentView({
    super.key,
    required this.payment,
    required this.checkout,
    required this.onViewOrder,
    required this.onTryAgain,
    required this.onTryAnotherCard,
    required this.onBackToCart,
    this.autoOpenDelay = const Duration(milliseconds: 1500),
    this.cardCheckTime = const Duration(milliseconds: 800),
  });

  final PaymentState payment;
  final CheckoutState checkout;

  final VoidCallback onViewOrder;
  final VoidCallback onTryAgain;
  final VoidCallback onTryAnotherCard;
  final VoidCallback onBackToCart;

  // After success, the order opens by itself after this time.
  final Duration autoOpenDelay;

  // "Checking card" turns to "Paying" after this time.
  final Duration cardCheckTime;

  CardPaymentStage get stage =>
      cardPaymentStageOf(payment, checkout) ?? CardPaymentStage.processing;

  @override
  State<CheckoutPaymentView> createState() => _CheckoutPaymentViewState();
}

class _CheckoutPaymentViewState extends State<CheckoutPaymentView> {
  Timer? _autoOpen;
  bool _opened = false;

  Timer? _cardCheck;
  bool _cardChecked = false;

  @override
  void initState() {
    super.initState();
    _startCardCheck();
    _startAutoOpen();
  }

  @override
  void didUpdateWidget(CheckoutPaymentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stage = widget.stage;
    if (stage == oldWidget.stage) return;

    // "Try again" pays again, so the steps start over.
    if (stage == CardPaymentStage.processing) {
      _cardCheck?.cancel();
      _cardCheck = null;
      _cardChecked = false;
      _startCardCheck();
    }
    _startAutoOpen();
  }

  void _startCardCheck() {
    if (widget.payment.status != DemoPaymentStatus.processing) return;
    if (_cardCheck != null || _cardChecked) return;
    _cardCheck = Timer(widget.cardCheckTime, () {
      if (mounted) setState(() => _cardChecked = true);
    });
  }

  void _startAutoOpen() {
    if (widget.stage != CardPaymentStage.success) return;
    if (_autoOpen != null || _opened) return;
    _autoOpen = Timer(widget.autoOpenDelay, _openOrder);
  }

  // Runs once, from the timer or the "View order" button.
  void _openOrder() {
    if (_opened) return;
    _opened = true;
    _autoOpen?.cancel();
    widget.onViewOrder();
  }

  @override
  void dispose() {
    _autoOpen?.cancel();
    _cardCheck?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final stage = widget.stage;

    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(stage),
                    child: _body(stage),
                  ),
                ),
              ),
              const _DemoNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(CardPaymentStage stage) {
    final card = widget.payment.card;
    final cardName = card?.title ?? 'Card';
    final price = formatPrice(widget.payment.amount);

    switch (stage) {
      case CardPaymentStage.processing:
        return _StageLayout(
          icon: _CardLogoBox(card: card),
          title: 'Processing payment',
          lines: [price],
          steps: PaymentSteps(
            current: paymentStepOf(
              widget.payment,
              widget.checkout,
              cardChecked: _cardChecked,
            ),
          ),
        );

      case CardPaymentStage.success:
        return _StageLayout(
          icon: const _PopIcon(
            icon: Icons.check_rounded,
            color: AppTheme.successGreen,
            background: AppTheme.successBg,
          ),
          title: 'Payment successful',
          lines: ['$price · $cardName'],
          steps: const PaymentSteps(current: 3),
          buttons: [
            FilledButton(
              onPressed: _openOrder,
              child: const Text('View order'),
            ),
          ],
          hint: 'Opens by itself',
        );

      case CardPaymentStage.declined:
        return _StageLayout(
          icon: const _PopIcon(
            icon: Icons.close_rounded,
            color: AppTheme.dangerRed,
            background: AppTheme.dangerBg,
          ),
          title: 'Payment declined',
          lines: const ['No order was placed.'],
          buttons: [
            FilledButton(
              onPressed: widget.onTryAnotherCard,
              child: const Text('Try another card'),
            ),
            TextButton(
              onPressed: widget.onBackToCart,
              child: const Text('Back to cart'),
            ),
          ],
        );

      case CardPaymentStage.failed:
        return _StageLayout(
          icon: const _PopIcon(
            icon: Icons.close_rounded,
            color: AppTheme.dangerRed,
            background: AppTheme.dangerBg,
          ),
          title: 'Payment not done',
          lines: [
            widget.checkout.errorMessage ?? 'Something went wrong.',
            'No money was taken (demo).',
          ],
          buttons: [
            FilledButton(
              onPressed: widget.onTryAgain,
              child: const Text('Try again'),
            ),
            TextButton(
              onPressed: widget.onBackToCart,
              child: const Text('Back to cart'),
            ),
          ],
        );
    }
  }
}

class _StageLayout extends StatelessWidget {
  const _StageLayout({
    required this.icon,
    required this.title,
    required this.lines,
    this.steps,
    this.buttons = const [],
    this.hint,
  });

  final Widget icon;
  final String title;
  final List<String> lines;
  final Widget? steps;
  final List<Widget> buttons;

  // Small grey text under the buttons.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 20),
            // Read out by screen readers when it changes.
            Semantics(
              liveRegion: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  line,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 16,
                  ),
                ),
              ),
            if (steps != null) ...[
              const SizedBox(height: 20),
              ?steps,
            ],
            if (buttons.isNotEmpty) ...[
              const SizedBox(height: 28),
              for (final button in buttons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(width: double.infinity, child: button),
                ),
            ],
            if (hint != null)
              Text(
                hint!,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardLogoBox extends StatelessWidget {
  const _CardLogoBox({required this.card});

  final PaymentCard? card;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CardBrandLogo(
        brand: card?.brand,
        height: 30,
        visaColor: const Color(0xFF1A1F71),
      ),
    );
  }
}

// A round icon in a soft circle that pops in with a small bounce.
class _PopIcon extends StatelessWidget {
  const _PopIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return EnterAnimation(
      scaleFrom: 0.5,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      child: Container(
        width: 96,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 38),
        ),
      ),
    );
  }
}

class _DemoNote extends StatelessWidget {
  const _DemoNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_rounded, size: 16, color: AppTheme.textMuted),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Demo payment, no real charge.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }
}