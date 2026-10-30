import 'package:equatable/equatable.dart';

import '../domain/payment_card.dart';

enum CardsStatus { loading, loaded, failure }

class CardsState extends Equatable {
  const CardsState({
    this.status = CardsStatus.loading,
    this.cards = const [],
    this.errorMessage,
    this.isWorking = false,
    this.notice,
    this.noticeId = 0,
  });

  final CardsStatus status;

  // The default card first, then the newest.
  final List<PaymentCard> cards;

  // Why the cards could not be loaded.
  final String? errorMessage;

  // True while a card is being added, deleted, or made default.
  final bool isWorking;

  // A message for the customer. A new noticeId means "show it now".
  final String? notice;
  final int noticeId;

  // The default card, if it has not expired. Checkout selects it first.
  PaymentCard? usableDefault(DateTime now) {
    for (final card in cards) {
      if (card.isDefault && !card.isExpired(now)) return card;
    }
    return null;
  }

  CardsState copyWith({
    CardsStatus? status,
    List<PaymentCard>? cards,
    bool? isWorking,
    String? notice,
    int? noticeId,
  }) {
    return CardsState(
      status: status ?? this.status,
      cards: cards ?? this.cards,
      errorMessage: errorMessage,
      isWorking: isWorking ?? this.isWorking,
      notice: notice ?? this.notice,
      noticeId: noticeId ?? this.noticeId,
    );
  }

  @override
  List<Object?> get props => [
        status,
        cards,
        errorMessage,
        isWorking,
        notice,
        noticeId,
      ];
}