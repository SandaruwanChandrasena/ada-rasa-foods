import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/price_format.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../cart/presentation/cart_cubit.dart';
import '../../cart/presentation/cart_state.dart';
import '../../payments/domain/payment_card.dart';
import '../../payments/domain/payment_choice.dart';
import '../../payments/presentation/cards_cubit.dart';
import '../../payments/presentation/cards_state.dart';
import '../../payments/presentation/enter_animation.dart';
import '../../payments/presentation/payment_cubit.dart';
import '../../payments/presentation/payment_options.dart';
import '../../payments/presentation/payment_state.dart';
import 'checkout_cubit.dart';
import 'checkout_payment_view.dart';
import 'checkout_state.dart';

// Checkout: check the order, pick how to pay, and place it (CUS-4).
class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthCubit>().state.user?.uid ?? '';

    return MultiBlocProvider(
      providers: [
        BlocProvider<CheckoutCubit>(
          create: (_) => CheckoutCubit(sl(), sl()),
        ),
        // Live saved cards, for the payment list.
        BlocProvider<CardsCubit>(
          create: (_) => sl<CardsCubit>()..start(userId),
        ),
        // The fake card payment (2 seconds, 0002 always fails).
        BlocProvider<PaymentCubit>(create: (_) => PaymentCubit()),
      ],
      child: const _CheckoutView(),
    );
  }
}

class _CheckoutView extends StatefulWidget {
  const _CheckoutView();

  @override
  State<_CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<_CheckoutView> {
  PaymentChoice _choice = const PaymentChoice();

  // Card ids from before "Add card". Set while we wait for the new card.
  Set<String>? _idsBeforeAdd;

  void _select(PaymentCard? card) {
    setState(() {
      _choice =
          card == null ? const PaymentChoice.cash() : PaymentChoice.card(card);
    });
  }

  Future<void> _manageCards() async {
    final cards = context.read<CardsCubit>().state;

    // With no cards, go straight to "Add card".
    if (cards.status == CardsStatus.loaded && cards.cards.isEmpty) {
      final oldIds = {for (final card in cards.cards) card.id};
      final saved = await context.push<bool>(AppRoutes.addCard);
      if (!mounted || saved != true) return;
      _idsBeforeAdd = oldIds;
      _pickNewCard(context.read<CardsCubit>().state);
      return;
    }

    await context.push(AppRoutes.myCards);
  }

  // Selects the card just added, once it shows in the live list.
  void _pickNewCard(CardsState cards) {
    final oldIds = _idsBeforeAdd;
    if (oldIds == null) return;
    final card = PaymentChoice.newCard(
      cards.cards,
      oldIds,
      context.read<CardsCubit>().now,
    );
    if (card == null) return;
    _idsBeforeAdd = null;
    _select(card);
  }

  // Cash: place the order now. Card: the demo payment first.
  void _place(PaymentCard? card) {
    if (card != null) {
      _payByCard(card);
      return;
    }
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    context.read<CheckoutCubit>().placeOrder(
          user: user,
          cart: context.read<CartCubit>().state,
        );
  }

  Future<void> _payByCard(PaymentCard card) async {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    final payment = context.read<PaymentCubit>();
    final checkout = context.read<CheckoutCubit>();
    final cartCubit = context.read<CartCubit>();

    checkout.reset();
    final approved = await payment.pay(
      card: card,
      amount: cartCubit.state.total,
    );
    if (!approved || !mounted) return;

    // "Processing" stays on screen while the order is saved.
    // We use the newest cart, in case it changed during the payment.
    await checkout.placeOrder(
      user: user,
      cart: cartCubit.state,
      card: card,
    );
  }

  // Closes the payment cover, so another card or cash can be chosen.
  void _tryAnotherCard() {
    context.read<PaymentCubit>().reset();
    context.read<CheckoutCubit>().reset();
  }

  // Pays again with the same card, after the order could not be saved.
  void _tryAgain() {
    final card = context.read<PaymentCubit>().state.card;
    _tryAnotherCard();
    if (card != null) _payByCard(card);
  }

  void _backToCart() {
    _tryAnotherCard();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.cart);
    }
  }

  void _openOrder() {
    final orderId = context.read<CheckoutCubit>().state.orderId;
    if (orderId == null) return;
    // go() replaces checkout, so Back goes home, not to checkout.
    context.go(AppRoutes.orderStatus(orderId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CardsCubit, CardsState>(
      listenWhen: (previous, current) => previous.cards != current.cards,
      listener: (context, cards) => _pickNewCard(cards),
      child: BlocConsumer<CheckoutCubit, CheckoutState>(
        listenWhen: (previous, current) =>
            previous.status != current.status,
        listener: _onCheckoutChanged,
        builder: (context, checkout) {
          return BlocBuilder<PaymentCubit, PaymentState>(
            builder: (context, payment) {
              final stage = cardPaymentStageOf(payment, checkout);
              final payingCard = payment.card;
              final covered = stage != null && payingCard != null;

              // Back is blocked while placing or paying, so the cart is
              // always cleared and no payment is left half done.
              return PopScope(
                canPop: !checkout.isPlacing && !covered,
                onPopInvokedWithResult: (didPop, _) {
                  if (didPop) return;
                  // Back on a failed step works like "Try another card".
                  if (stage == CardPaymentStage.declined ||
                      stage == CardPaymentStage.failed) {
                    _tryAnotherCard();
                  }
                },
                child: Stack(
                  children: [
                    _buildCheckout(
                      checkout: checkout,
                      busy: checkout.isPlacing ||
                          payment.status != DemoPaymentStatus.idle,
                    ),
                    if (stage != null && payingCard != null)
                      Positioned.fill(
                        child: EnterAnimation(
                          duration: const Duration(milliseconds: 200),
                          child: CheckoutPaymentView(
                            stage: stage,
                            card: payingCard,
                            amount: payment.amount,
                            errorMessage: checkout.errorMessage,
                            onViewOrder: _openOrder,
                            onTryAgain: _tryAgain,
                            onTryAnotherCard: _tryAnotherCard,
                            onBackToCart: _backToCart,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCheckout({
    required CheckoutState checkout,
    required bool busy,
  }) {
    return BlocBuilder<CardsCubit, CardsState>(
      builder: (context, cards) {
        final cardsCubit = context.read<CardsCubit>();
        final card = _choice.cardFrom(cards.cards, cardsCubit.now);

        return BlocBuilder<CartCubit, CartState>(
          builder: (context, cart) {
            final placed = checkout.status == CheckoutStatus.placed;

            return Scaffold(
              appBar: AppBar(title: const Text('Checkout')),
              body: cart.cart.isEmpty && !placed
                  ? const _EmptyCheckout()
                  : _OrderSummary(
                      cart: cart,
                      payment: PaymentOptions(
                        cards: cards,
                        now: cardsCubit.now,
                        selected: card,
                        onSelected: _select,
                        onRetry: cardsCubit.retry,
                        onManageCards: _manageCards,
                        enabled: !busy,
                      ),
                    ),
              bottomNavigationBar: cart.cart.isEmpty
                  ? null
                  : _PlaceOrderBar(
                      cart: cart,
                      checkout: checkout,
                      card: card,
                      busy: busy,
                      cardsLoading: cards.status == CardsStatus.loading,
                      onPlace: () => _place(card),
                    ),
            );
          },
        );
      },
    );
  }

  void _onCheckoutChanged(BuildContext context, CheckoutState state) {
    final messenger = ScaffoldMessenger.of(context);

    // A card payment shows its own full screen, not a message.
    final byCard = context.read<PaymentCubit>().state.status !=
        DemoPaymentStatus.idle;

    switch (state.status) {
      case CheckoutStatus.placed:
        final orderId = state.orderId;
        if (orderId == null) return;
        final cartCubit = context.read<CartCubit>();
        if (byCard) {
          // "Payment successful" shows, then it opens the order.
          cartCubit.clear();
          return;
        }
        // go() replaces checkout, so Back goes home, not to checkout.
        context.go(AppRoutes.orderStatus(orderId));
        cartCubit.clear();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Your order is placed.'),
              duration: Duration(seconds: 3),
            ),
          );
      case CheckoutStatus.failure:
        if (byCard) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Please try again.'),
              duration: const Duration(seconds: 5),
            ),
          );
      case CheckoutStatus.ready:
      case CheckoutStatus.placing:
        break;
    }
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.cart, required this.payment});

  final CartState cart;
  final Widget payment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bold = textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final problem = cart.canCheckout ? null : cart.problemMessage;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (problem != null) _ProblemBanner(message: problem),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.storefront_outlined),
          title: Text(cart.cart.restaurantName, style: bold),
          subtitle: const Text('Pickup order. You collect it yourself.'),
        ),
        const Divider(),
        const SizedBox(height: 8),
        Text('Your order', style: bold),
        const SizedBox(height: 8),
        for (final item in cart.cart.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    '${item.quantity} x',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Text(item.name)),
                const SizedBox(width: 12),
                Text(formatPrice(item.lineTotal)),
              ],
            ),
          ),
        const Divider(height: 24),
        Row(
          children: [
            Text('Total', style: bold),
            const Spacer(),
            Text(formatPrice(cart.total), style: bold),
          ],
        ),
        const SizedBox(height: 24),
        Text('Payment', style: bold),
        const SizedBox(height: 8),
        payment,
      ],
    );
  }
}

class _ProblemBanner extends StatelessWidget {
  const _ProblemBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _PlaceOrderBar extends StatelessWidget {
  const _PlaceOrderBar({
    required this.cart,
    required this.checkout,
    required this.card,
    required this.busy,
    required this.cardsLoading,
    required this.onPlace,
  });

  final CartState cart;
  final CheckoutState checkout;

  // The chosen card. Null means cash.
  final PaymentCard? card;

  // True while placing a cash order or paying by card.
  final bool busy;

  // Wait for the cards, so the default card is not skipped by mistake.
  final bool cardsLoading;

  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    final canPlace = cart.canCheckout &&
        !cardsLoading &&
        !busy &&
        checkout.status != CheckoutStatus.placed;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: FilledButton(
          onPressed: canPlace ? onPlace : null,
          child: checkout.isPlacing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  card == null
                      ? 'Place order'
                      : 'Pay ${formatPrice(cart.total)}',
                ),
        ),
      ),
    );
  }
}

class _EmptyCheckout extends StatelessWidget {
  const _EmptyCheckout();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your cart is empty.'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.customer),
              child: const Text('Browse restaurants'),
            ),
          ],
        ),
      ),
    );
  }
}