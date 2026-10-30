import 'payment_card.dart';

// Saved demo cards in users/{uid}/cards (CUS-9).
// Futures throw DataFailure. Streams report errors as DataFailure.
abstract class CardRepository {
  // Most saved cards per customer.
  static const int maxCards = 5;

  // The default card first, then the newest.
  Stream<List<PaymentCard>> watchCards(String userId);

  // The first card becomes the default. No copies, and at most 5 cards.
  Future<void> addCard(String userId, PaymentCard card);

  // If the default card is deleted, the newest card left becomes default.
  Future<void> deleteCard(String userId, PaymentCard card);

  Future<void> setDefault(String userId, String cardId);
}