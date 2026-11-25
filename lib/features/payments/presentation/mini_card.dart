import 'package:material_ui/material_ui.dart';

import '../domain/payment_card.dart';
import 'card_art.dart';

// A small picture of a saved card, made from the Add card art.
class MiniCard extends StatelessWidget {
  const MiniCard({super.key, required this.card});

  static const double width = 72;
  static const double height = 46;

  final PaymentCard card;

  @override
  Widget build(BuildContext context) {
    // The row next to it already says the card name for screen readers.
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              const Positioned.fill(child: CardBackground()),
              const Positioned(left: 7, top: 8, child: CardChip(width: 13)),
              Positioned(
                left: 7,
                bottom: 6,
                child: Text(
                  '•••• ${card.last4}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontFamily: 'monospace',
                    height: 1,
                  ),
                ),
              ),
              Positioned(
                right: 6,
                top: 7,
                child: CardBrandLogo(brand: card.brand, height: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}