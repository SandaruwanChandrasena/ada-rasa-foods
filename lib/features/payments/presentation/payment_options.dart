import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/payment_card.dart';
import '../domain/payment_choice.dart';
import 'card_art.dart';
import 'cards_state.dart';

// The "Payment" part of checkout: Cash and Card tiles, then the cards.
class PaymentOptions extends StatelessWidget {
  const PaymentOptions({
    super.key,
    required this.cards,
    required this.now,
    required this.selected,
    required this.onSelected,
    required this.onRetry,
    required this.onManageCards,
    this.enabled = true,
  });

  final CardsState cards;
  final DateTime now;

  // The chosen card. Null means cash.
  final PaymentCard? selected;

  final ValueChanged<PaymentCard?> onSelected;
  final VoidCallback onRetry;
  final VoidCallback onManageCards;

  // False while the order is being placed.
  final bool enabled;

  bool get _cardChosen => selected != null;

  // The card to pick when the Card tile is tapped.
  PaymentCard? get _firstUsableCard {
    final fallback = PaymentChoice.usableDefault(cards.cards, now);
    if (fallback != null) return fallback;
    for (final card in cards.cards) {
      if (!card.isExpired(now)) return card;
    }
    return null;
  }

  void _tapCardTile() {
    if (_cardChosen) return;
    final card = _firstUsableCard;
    if (card != null) {
      onSelected(card);
    } else {
      // No usable card yet, so open Add card or My cards.
      onManageCards();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = cards.status == CardsStatus.loaded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _PayTile(
                key: const ValueKey('pay_cash'),
                icon: Icons.payments_rounded,
                title: 'Cash',
                subtitle: 'At pickup',
                selected: !_cardChosen,
                onTap: enabled ? () => onSelected(null) : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PayTile(
                key: const ValueKey('pay_card'),
                icon: Icons.credit_card_rounded,
                title: 'Card',
                subtitle: 'Demo card',
                selected: _cardChosen,
                // Wait for the cards, so we know which one to pick.
                onTap: enabled && loaded ? _tapCardTile : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._cardPart(),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: enabled ? onManageCards : null,
            icon: const Icon(Icons.credit_card_rounded),
            label: const Text('Manage cards'),
          ),
        ),
      ],
    );
  }

  List<Widget> _cardPart() {
    switch (cards.status) {
      case CardsStatus.loading:
        return const [_LoadingRow()];

      case CardsStatus.failure:
        return [_FailureRow(onRetry: onRetry)];

      case CardsStatus.loaded:
        // The card list shows only while Card is chosen.
        if (!_cardChosen) return const [];
        return [
          for (final card in cards.cards)
            _cardRow(card, expired: card.isExpired(now)),
        ];
    }
  }

  Widget _cardRow(PaymentCard card, {required bool expired}) {
    return _CardRow(
      key: ValueKey('card_${card.id}'),
      card: card,
      selected: !expired && selected?.id == card.id,
      // An expired card can't be chosen.
      onTap: enabled && !expired ? () => onSelected(card) : null,
      expired: expired,
    );
  }
}

// One of the 2 big tiles. The chosen one has an orange border.
class _PayTile extends StatelessWidget {
  const _PayTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.brandOrange : AppTheme.textMuted;

    return Semantics(
      selected: selected,
      button: onTap != null,
      child: Material(
        color: selected ? AppTheme.softOrange : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppTheme.brandOrange : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
                child: Column(
                  children: [
                    Icon(icon, color: color, size: 30),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? AppTheme.deepOrange
                            : AppTheme.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.brandOrange,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// A saved card under the tiles. The chosen one has an orange border.
class _CardRow extends StatelessWidget {
  const _CardRow({
    super.key,
    required this.card,
    required this.selected,
    required this.onTap,
    required this.expired,
  });

  // Makes an expired card look faded. A layer, not Opacity.
  static const Color fade = Color(0x99FFFFFF);

  final PaymentCard card;
  final bool selected;
  final VoidCallback? onTap;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);

    final row = Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      foregroundDecoration: expired
          ? BoxDecoration(color: fade, borderRadius: radius)
          : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(
          color: selected ? AppTheme.brandOrange : AppTheme.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CardBrandLogo(
              brand: card.brand,
              height: 20,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  expired
                      ? 'Expired ${card.expiryText}'
                      : 'Expires ${card.expiryText}',
                  style: TextStyle(
                    color: expired ? AppTheme.dangerRed : AppTheme.textMuted,
                    fontSize: 12,
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
                          color: AppTheme.deepOrange,
                          background: AppTheme.softOrange,
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
          const SizedBox(width: 8),
          if (!expired)
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppTheme.brandOrange : AppTheme.border,
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        button: onTap != null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: row,
          ),
        ),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          // Expanded lets long text wrap on a small screen or big font.
          Expanded(
            child: Text(
              'Loading your cards...',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureRow extends StatelessWidget {
  const _FailureRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.error_rounded,
          size: 18,
          color: AppTheme.textMuted,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Cards could not load.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}