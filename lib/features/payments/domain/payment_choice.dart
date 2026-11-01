import 'package:equatable/equatable.dart';

import 'payment_card.dart';

// What the customer picked at checkout (CUS-4). No card id means cash.
class PaymentChoice extends Equatable {
  // Nothing picked yet, so the default card is used if it can be.
  const PaymentChoice() : cardId = null, picked = false;

  const PaymentChoice.cash() : cardId = null, picked = true;

  PaymentChoice.card(PaymentCard card) : cardId = card.id, picked = true;

  final String? cardId;

  // True after the customer taps a row.
  final bool picked;

  bool get isCash => picked && cardId == null;

  // The card to pay with now. Null means cash.
  PaymentCard? cardFrom(List<PaymentCard> cards, DateTime now) {
    if (isCash) return null;

    if (picked) {
      for (final card in cards) {
        if (card.id == cardId && !card.isExpired(now)) return card;
      }
    }

    // Not picked yet, or the picked card was deleted or expired.
    return usableDefault(cards, now);
  }

  // The default card, if it has not expired.
  static PaymentCard? usableDefault(List<PaymentCard> cards, DateTime now) {
    for (final card in cards) {
      if (card.isDefault && !card.isExpired(now)) return card;
    }
    return null;
  }

  // A usable card that was not in [oldIds], like one just added.
  static PaymentCard? newCard(
    List<PaymentCard> cards,
    Set<String> oldIds,
    DateTime now,
  ) {
    for (final card in cards) {
      if (!oldIds.contains(card.id) && !card.isExpired(now)) return card;
    }
    return null;
  }

  @override
  List<Object?> get props => [cardId, picked];
}