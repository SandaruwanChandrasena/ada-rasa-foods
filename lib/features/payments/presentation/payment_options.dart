import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/payment_card.dart';
import 'card_art.dart';
import 'cards_state.dart';

// The "Payment" list on checkout: cash first, then saved cards.
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OptionRow(
          selected: selected == null,
          onTap: enabled ? () => onSelected(null) : null,
          leading: Icon(
            Icons.payments_outlined,
            color: selected == null
                ? AppTheme.brandOrange
                : Colors.grey.shade700,
          ),
          title: 'Cash at pickup',
          subtitle: 'Pay when you collect your food.',
        ),
        ..._cardPart(context),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: enabled ? onManageCards : null,
            icon: const Icon(Icons.credit_card_outlined),
            label: const Text('Manage cards'),
          ),
        ),
      ],
    );
  }

  List<Widget> _cardPart(BuildContext context) {
    switch (cards.status) {
      case CardsStatus.loading:
        return const [_LoadingRow()];

      case CardsStatus.failure:
        return [_FailureRow(onRetry: onRetry)];

      case CardsStatus.loaded:
        return [
          for (final card in cards.cards)
            _cardRow(card, expired: card.isExpired(now)),
        ];
    }
  }

  Widget _cardRow(PaymentCard card, {required bool expired}) {
    return _OptionRow(
      key: ValueKey('card_${card.id}'),
      selected: !expired && selected?.id == card.id,
      // An expired card can't be chosen.
      onTap: enabled && !expired ? () => onSelected(card) : null,
      faded: expired,
      leading: Container(
        width: 52,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: CardBrandLogo(
          brand: card.brand,
          height: 20,
          visaColor: const Color(0xFF1A1F71),
        ),
      ),
      title: card.title,
      subtitle: expired
          ? 'Expired ${card.expiryText}'
          : 'Expires ${card.expiryText}',
      subtitleColor: expired ? Colors.red.shade700 : null,
      labels: [
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
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.labels = const [],
    this.faded = false,
  });

  final bool selected;
  final VoidCallback? onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final List<Widget> labels;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final row = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppTheme.brandOrange : Colors.grey.shade300,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: subtitleColor ?? Colors.grey.shade600,
                  ),
                ),
                if (labels.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: labels),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!faded)
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? AppTheme.brandOrange : Colors.grey.shade400,
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
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            // An expired card looks grey and faded.
            child: faded ? Opacity(opacity: 0.5, child: row) : row,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          // Expanded lets long text wrap on a small screen or big font.
          Expanded(
            child: Text(
              'Loading your cards...',
              style: TextStyle(color: Colors.grey.shade600),
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
        Icon(Icons.error_outline, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Cards could not load.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}