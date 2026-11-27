import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../auth/domain/phone_checks.dart';
import '../../../auth/presentation/auth_cubit.dart';
import '../../../cart/presentation/cart_cubit.dart';
import '../../../cart/presentation/cart_state.dart';
import '../../../payments/domain/payment_card.dart';
import '../../../payments/domain/payment_choice.dart';
import '../../../payments/presentation/cards/cards_cubit.dart';
import '../../../payments/presentation/cards/cards_state.dart';
import '../../../payments/presentation/cards/enter_animation.dart';
import '../../../payments/presentation/pay/payment_cubit.dart';
import '../../../payments/presentation/pay/payment_options.dart';
import '../../../payments/presentation/pay/payment_state.dart';
import 'checkout_cubit.dart';
import 'checkout_payment_view.dart';
import 'checkout_sections.dart';
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
                    if (covered)
                      Positioned.fill(
                        child: EnterAnimation(
                          duration: const Duration(milliseconds: 200),
                          child: CheckoutPaymentView(
                            payment: payment,
                            checkout: checkout,
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
            // Rebuilds when the phone is added or changed.
            final phone = context.select<AuthCubit, String>(
              (auth) => auth.state.user?.phone ?? '',
            );

            return Scaffold(
              appBar: AppBar(title: const Text('Checkout')),
              body: cart.cart.isEmpty && !placed
                  ? const _EmptyCheckout()
                  : _OrderSummary(
                      cart: cart,
                      contact: CheckoutPhoneBox(
                        phone: phone,
                        onAddPhone: () => context.push(AppRoutes.addPhone),
                        onChangePhone: () =>
                            context.push(AppRoutes.editProfile),
                      ),
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
                      busy: busy,
                      cardsLoading: cards.status == CardsStatus.loading,
                      phoneMissing: !PhoneChecks.isValid(phone),
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
  const _OrderSummary({
    required this.cart,
    required this.contact,
    required this.payment,
  });

  final CartState cart;
  final Widget contact;
  final Widget payment;

  @override
  Widget build(BuildContext context) {
    final problem = cart.canCheckout ? null : cart.problemMessage;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (problem != null) CheckoutProblemBanner(message: problem),
        CheckoutPickupCard(restaurantName: cart.cart.restaurantName),
        const SizedBox(height: 12),
        CheckoutOrderCard(items: cart.cart.items, total: cart.total),
        const SizedBox(height: 12),
        SectionCard(
          icon: Icons.phone_rounded,
          title: 'Contact',
          child: contact,
        ),
        const SizedBox(height: 12),
        SectionCard(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Payment',
          child: payment,
        ),
      ],
    );
  }
}

class _PlaceOrderBar extends StatelessWidget {
  const _PlaceOrderBar({
    required this.cart,
    required this.checkout,
    required this.busy,
    required this.cardsLoading,
    required this.phoneMissing,
    required this.onPlace,
  });

  final CartState cart;
  final CheckoutState checkout;

  // True while placing a cash order or paying by card.
  final bool busy;

  // Wait for the cards, so the default card is not skipped by mistake.
  final bool cardsLoading;

  // No order without a phone, so the restaurant can call.
  final bool phoneMissing;

  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    final canPlace = cart.canCheckout &&
        !cardsLoading &&
        !phoneMissing &&
        !busy &&
        checkout.status != CheckoutStatus.placed;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: PlaceOrderButton(
          total: cart.total,
          placing: checkout.isPlacing,
          onPressed: canPlace ? onPlace : null,
        ),
      ),
    );
  }
}

// The phone the restaurant will call. Asks for one when it is missing.
class CheckoutPhoneBox extends StatelessWidget {
  const CheckoutPhoneBox({
    super.key,
    required this.phone,
    required this.onAddPhone,
    required this.onChangePhone,
  });

  final String phone;
  final VoidCallback onAddPhone;
  final VoidCallback onChangePhone;

  @override
  Widget build(BuildContext context) {
    if (!PhoneChecks.isValid(phone)) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        decoration: BoxDecoration(
          color: AppTheme.softOrange,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.brandOrange),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.phone_in_talk_rounded,
                  color: AppTheme.brandOrange,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Add your phone number so the restaurant can call you.',
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onAddPhone,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add phone'),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The restaurant may call you at',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                PhoneChecks.format(phone),
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: AppTheme.softOrange,
            shape: const StadiumBorder(),
          ),
          onPressed: onChangePhone,
          child: const Text('Change'),
        ),
      ],
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