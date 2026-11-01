import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../core/utils/price_format.dart';
import '../../payments/domain/payment_card.dart';
import '../../payments/presentation/card_art.dart';
import '../../payments/presentation/enter_animation.dart';
import '../../payments/presentation/payment_state.dart';
import 'checkout_state.dart';

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
    required this.stage,
    required this.card,
    required this.amount,
    required this.onViewOrder,
    required this.onTryAgain,
    required this.onTryAnotherCard,
    required this.onBackToCart,
    this.errorMessage,
    this.autoOpenDelay = const Duration(milliseconds: 1500),
  });

  final CardPaymentStage stage;
  final PaymentCard card;

  // Whole rupees.
  final int amount;

  // Why the order could not be saved (failed stage).
  final String? errorMessage;

  final VoidCallback onViewOrder;
  final VoidCallback onTryAgain;
  final VoidCallback onTryAnotherCard;
  final VoidCallback onBackToCart;

  // After success, the order opens by itself after this time.
  final Duration autoOpenDelay;

  @override
  State<CheckoutPaymentView> createState() => _CheckoutPaymentViewState();
}

class _CheckoutPaymentViewState extends State<CheckoutPaymentView> {
  Timer? _autoOpen;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _startAutoOpen();
  }

  @override
  void didUpdateWidget(CheckoutPaymentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stage != oldWidget.stage) _startAutoOpen();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

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
                    key: ValueKey(widget.stage),
                    child: _body(context),
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

  Widget _body(BuildContext context) {
    final card = widget.card;
    final price = formatPrice(widget.amount);

    switch (widget.stage) {
      case CardPaymentStage.processing:
        return _StageLayout(
          icon: _CardLogoBox(card: card),
          showSpinner: true,
          title: 'Processing payment...',
          lines: [card.title, price],
        );

      case CardPaymentStage.success:
        return _StageLayout(
          icon: const _PopIcon(
            icon: Icons.check_rounded,
            color: Color(0xFF2E7D32),
          ),
          title: 'Payment successful',
          lines: ['$price paid with ${card.title}'],
          buttons: [
            FilledButton(
              onPressed: _openOrder,
              child: const Text('View order'),
            ),
          ],
        );

      case CardPaymentStage.declined:
        return _StageLayout(
          icon: _PopIcon(icon: Icons.close_rounded, color: _red),
          title: 'Payment declined',
          lines: const [
            'Your card was declined (demo).',
            'No order was placed.',
          ],
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
          icon: _PopIcon(icon: Icons.close_rounded, color: _red),
          title: 'Payment not done',
          lines: [
            widget.errorMessage ?? 'Something went wrong.',
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

  Color get _red => Colors.red.shade700;
}

class _StageLayout extends StatelessWidget {
  const _StageLayout({
    required this.icon,
    required this.title,
    required this.lines,
    this.showSpinner = false,
    this.buttons = const [],
  });

  final Widget icon;
  final String title;
  final List<String> lines;
  final bool showSpinner;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 24),
            if (showSpinner) ...[
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 20),
            ],
            // Read out by screen readers when it changes.
            Semantics(
              liveRegion: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  line,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            if (buttons.isNotEmpty) ...[
              const SizedBox(height: 32),
              for (final button in buttons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(width: double.infinity, child: button),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardLogoBox extends StatelessWidget {
  const _CardLogoBox({required this.card});

  final PaymentCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CardBrandLogo(
        brand: card.brand,
        height: 30,
        visaColor: const Color(0xFF1A1F71),
      ),
    );
  }
}

// A round icon that pops in with a small bounce.
class _PopIcon extends StatelessWidget {
  const _PopIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return EnterAnimation(
      scaleFrom: 0.5,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 48),
      ),
    );
  }
}

class _DemoNote extends StatelessWidget {
  const _DemoNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Demo payment, no real charge.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}