import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../domain/card_repository.dart';
import '../domain/payment_card.dart';
import 'card_art.dart';
import 'cards_cubit.dart';
import 'cards_state.dart';

// My cards: saved demo cards, set default, delete, add (CUS-9).
class MyCardsScreen extends StatelessWidget {
  const MyCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthCubit>().state.user?.uid ?? '';

    return BlocProvider<CardsCubit>(
      create: (_) => sl<CardsCubit>()..start(userId),
      child: const MyCardsView(),
    );
  }
}

// Public so widget tests can give it a CardsCubit of their own.
class MyCardsView extends StatelessWidget {
  const MyCardsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CardsCubit, CardsState>(
      listenWhen: (previous, current) => previous.noticeId != current.noticeId,
      listener: (context, state) {
        final notice = state.notice;
        if (notice == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(notice)));
      },
      builder: (context, state) {
        final full = state.cards.length >= CardRepository.maxCards;

        return Scaffold(
          appBar: AppBar(
            title: const Text('My cards'),
            // A thin bar while a change is saving.
            bottom: state.isWorking
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(3),
                    child: LinearProgressIndicator(minHeight: 3),
                  )
                : null,
          ),
          body: switch (state.status) {
            CardsStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            CardsStatus.failure => _MessageView(
                message: state.errorMessage ?? 'Something went wrong.',
                buttonText: 'Retry',
                onPressed: () => context.read<CardsCubit>().retry(),
              ),
            CardsStatus.loaded when state.cards.isEmpty =>
              const _EmptyCards(),
            CardsStatus.loaded => ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: state.cards.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) => _CardRow(
                  card: state.cards[index],
                  now: context.read<CardsCubit>().now,
                  enabled: !state.isWorking,
                ),
              ),
          },
          bottomNavigationBar: state.status == CardsStatus.loaded
              ? _AddCardBar(full: full)
              : null,
        );
      },
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.now,
    required this.enabled,
  });

  final PaymentCard card;
  final DateTime now;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final expired = card.isExpired(now);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: card.isDefault
              ? AppTheme.brandOrange
              : Colors.grey.shade300,
          width: card.isDefault ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // The logo on a light box.
          Container(
            width: 58,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: CardBrandLogo(
              brand: card.brand,
              height: 22,
              visaColor: const Color(0xFF1A1F71),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  expired
                      ? 'Expired ${card.expiryText}'
                      : 'Expires ${card.expiryText}',
                  style: textTheme.bodySmall?.copyWith(
                    color: expired
                        ? Colors.red.shade700
                        : Colors.grey.shade600,
                  ),
                ),
                if (card.isDefault || card.alwaysFails) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (card.isDefault)
                        const _Label(
                          text: 'Default',
                          color: AppTheme.brandOrange,
                          background: Color(0xFFFFF1EA),
                        ),
                      if (card.alwaysFails)
                        _Label(
                          text: 'Always fails (demo)',
                          color: Colors.grey.shade700,
                          background: Colors.grey.shade200,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Card options',
            enabled: enabled,
            onSelected: (choice) => choice == 'default'
                ? context.read<CardsCubit>().setDefault(card)
                : _confirmDelete(context),
            itemBuilder: (context) => [
              if (!card.isDefault)
                const PopupMenuItem(
                  value: 'default',
                  child: Text('Set as default'),
                ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  // Asks first, so a wrong tap does not delete a card.
  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<CardsCubit>();

    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${card.title}?'),
        content: Text(
          card.isDefault
              ? 'This is your default card. Your newest other card '
                  'will become the default.'
              : 'You can add it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            // The app theme makes FilledButton full width, so we set a size.
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 40),
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes ?? false) await cubit.deleteCard(card);
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AddCardBar extends StatelessWidget {
  const _AddCardBar({required this.full});

  // True when 5 cards are saved. Then no more can be added.
  final bool full;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (full) ...[
              Text(
                'You can save up to ${CardRepository.maxCards} cards. '
                'Delete one to add another.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: full ? null : () => context.push(AppRoutes.addCard),
              icon: const Icon(Icons.add),
              label: const Text('Add card'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCards extends StatelessWidget {
  const _EmptyCards();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.credit_card_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text('You have no saved cards yet.'),
            const SizedBox(height: 6),
            Text(
              'Add a demo card to pay at checkout.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
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