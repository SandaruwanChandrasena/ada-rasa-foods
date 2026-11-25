import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../domain/card_repository.dart';
import '../domain/payment_card.dart';
import 'cards_cubit.dart';
import 'cards_state.dart';
import 'mini_card.dart';

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
                icon: Icons.wifi_off_rounded,
                title: state.errorMessage ?? 'Something went wrong.',
                buttonText: 'Retry',
                onPressed: () => context.read<CardsCubit>().retry(),
              ),
            CardsStatus.loaded when state.cards.isEmpty =>
              const _EmptyCards(),
            CardsStatus.loaded => ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  for (final card in state.cards)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CardRow(
                        key: ValueKey('card_${card.id}'),
                        card: card,
                        now: context.read<CardsCubit>().now,
                        enabled: !state.isWorking,
                      ),
                    ),
                  const SizedBox(height: 4),
                  const _SafeNote(),
                ],
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
    super.key,
    required this.card,
    required this.now,
    required this.enabled,
  });

  // Makes an expired card look faded. A layer, not Opacity.
  static const Color fade = Color(0x99FFFFFF);

  final PaymentCard card;
  final DateTime now;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final expired = card.isExpired(now);
    final radius = BorderRadius.circular(16);
    final showSetDefault = !card.isDefault && !expired;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      foregroundDecoration: expired
          ? BoxDecoration(color: fade, borderRadius: radius)
          : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MiniCard(card: card),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.brand.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ending in ${card.last4}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                Text(
                  expired
                      ? 'Expired ${card.expiryText}'
                      : 'Expires ${card.expiryText}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: expired ? AppTheme.dangerRed : AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                if (card.isDefault || card.alwaysFails || showSetDefault) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (card.isDefault)
                        const _Label(
                          text: 'Default',
                          color: AppTheme.deepOrange,
                          background: AppTheme.softOrange,
                        ),
                      if (showSetDefault)
                        _SetDefaultButton(
                          onPressed: enabled
                              ? () => context
                                  .read<CardsCubit>()
                                  .setDefault(card)
                              : null,
                        ),
                      if (card.alwaysFails)
                        const _Label(
                          text: 'Always fails (demo)',
                          color: AppTheme.textMuted,
                          background: Color(0xFFEFEFEF),
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
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppTheme.textMuted,
            ),
            onSelected: (_) => _confirmDelete(context),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete')),
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
              backgroundColor: AppTheme.dangerRed,
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

class _SetDefaultButton extends StatelessWidget {
  const _SetDefaultButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.deepOrange,
        backgroundColor: AppTheme.softOrange,
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      onPressed: onPressed,
      child: const Text(
        'Set as default',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// Green note under the cards. True: only the last 4 digits are saved.
class _SafeNote extends StatelessWidget {
  const _SafeNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.successBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_rounded, color: AppTheme.successGreen),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your card information is safe. '
              'Only the last 4 digits are saved.',
              style: TextStyle(color: AppTheme.successGreen),
            ),
          ),
        ],
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
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: full ? null : () => context.push(AppRoutes.addCard),
              icon: const Icon(Icons.add_rounded),
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
    return const _MessageView(
      icon: Icons.credit_card_rounded,
      title: 'No saved cards yet',
      message: 'Add a demo card to pay at checkout.',
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    this.message,
    this.buttonText,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppTheme.softOrange,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppTheme.brandOrange),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ],
            if (buttonText != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onPressed, child: Text(buttonText!)),
            ],
          ],
        ),
      ),
    );
  }
}