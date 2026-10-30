import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/data_failure.dart';
import '../../../core/errors/firestore_errors.dart';
import '../domain/card_repository.dart';
import '../domain/payment_card.dart';
import 'card_model.dart';

class CardRepositoryImpl implements CardRepository {
  CardRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _cards(String userId) =>
      _firestore.collection('users').doc(userId).collection('cards');

  @override
  Stream<List<PaymentCard>> watchCards(String userId) {
    return _cards(userId)
        .snapshots()
        .map((snapshot) => _sorted(snapshot.docs))
        .mapErrorsToDataFailure();
  }

  @override
  Future<void> addCard(String userId, PaymentCard card) async {
    try {
      final cards = _sorted((await _cards(userId).get()).docs);

      if (cards.length >= CardRepository.maxCards) {
        throw const DataFailure('You can save up to 5 cards.');
      }
      if (cards.any((saved) => saved.isSameCardAs(card))) {
        throw const DataFailure('This card is already saved.');
      }

      final newCard = PaymentCard(
        brand: card.brand,
        last4: card.last4,
        holderName: card.holderName,
        expMonth: card.expMonth,
        expYear: card.expYear,
        isDefault: cards.isEmpty,
      );
      await _cards(userId).add(CardModel.toNewMap(newCard));
    } catch (error) {
      throw toDataFailure(error);
    }
  }

  @override
  Future<void> deleteCard(String userId, PaymentCard card) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_cards(userId).doc(card.id));

      if (card.isDefault) {
        final others = _sorted((await _cards(userId).get()).docs)
            .where((saved) => saved.id != card.id)
            .toList();
        // Sorted newest first, so the first one is the newest.
        if (others.isNotEmpty) {
          batch.update(
            _cards(userId).doc(others.first.id),
            {'isDefault': true},
          );
        }
      }
      await batch.commit();
    } catch (error) {
      throw toDataFailure(error);
    }
  }

  @override
  Future<void> setDefault(String userId, String cardId) async {
    try {
      final cards = (await _cards(userId).get()).docs;
      final batch = _firestore.batch();

      // One write per card that changes, so only one card is default.
      for (final doc in cards) {
        final shouldBeDefault = doc.id == cardId;
        if ((doc.data()['isDefault'] == true) != shouldBeDefault) {
          batch.update(doc.reference, {'isDefault': shouldBeDefault});
        }
      }
      await batch.commit();
    } catch (error) {
      throw toDataFailure(error);
    }
  }

  // The default card first, then the newest. Sorted on the phone.
  List<PaymentCard> _sorted(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final cards =
        docs.map((doc) => CardModel.fromMap(doc.id, doc.data())).toList();
    final far = DateTime(9999);

    cards.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      // A card still waiting for its server time counts as the newest.
      return (b.createdAt ?? far).compareTo(a.createdAt ?? far);
    });
    return cards;
  }
}