import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/payments/data/card_repository_impl.dart';
import 'package:ada_rasa_foods/features/payments/domain/card_brand.dart';
import 'package:ada_rasa_foods/features/payments/domain/payment_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentCard card(
  String last4, {
  CardBrand brand = CardBrand.visa,
  int expMonth = 8,
  int expYear = 2028,
}) {
  return PaymentCard(
    brand: brand,
    last4: last4,
    holderName: 'Nimal Perera',
    expMonth: expMonth,
    expYear: expYear,
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late CardRepositoryImpl repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = CardRepositoryImpl(firestore);
  });

  CollectionReference<Map<String, dynamic>> cardsOf(String userId) =>
      firestore.collection('users').doc(userId).collection('cards');

  // Adds a card straight to Firestore, with a fixed time.
  Future<void> addRaw(String id, String last4, DateTime createdAt,
      {bool isDefault = false}) {
    return cardsOf('u1').doc(id).set({
      'brand': 'visa',
      'last4': last4,
      'holderName': 'Nimal Perera',
      'expMonth': 8,
      'expYear': 2028,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
    });
  }

  group('addCard', () {
    test('saves only the safe fields, never a number or CVV', () async {
      await repository.addCard('u1', card('4242'));

      final docs = (await cardsOf('u1').get()).docs;
      expect(docs, hasLength(1));
      expect(docs.single.data().keys.toSet(), {
        'brand',
        'last4',
        'holderName',
        'expMonth',
        'expYear',
        'isDefault',
        'createdAt',
      });
      expect(docs.single.data()['brand'], 'visa');
      expect(docs.single.data()['last4'], '4242');
    });

    test('the first card becomes the default', () async {
      await repository.addCard('u1', card('4242'));

      final cards = await repository.watchCards('u1').first;
      expect(cards.single.isDefault, isTrue);
    });

    test('the second card is not the default', () async {
      await repository.addCard('u1', card('4242'));
      await repository.addCard(
        'u1',
        card('4444', brand: CardBrand.mastercard),
      );

      final cards = await repository.watchCards('u1').first;
      expect(cards.where((c) => c.isDefault).map((c) => c.last4), ['4242']);
    });

    test('the same card cannot be saved twice', () async {
      await repository.addCard('u1', card('4242'));

      await expectLater(
        repository.addCard('u1', card('4242')),
        throwsA(const DataFailure('This card is already saved.')),
      );
      expect((await cardsOf('u1').get()).docs, hasLength(1));
    });

    test('the same last 4 with another expiry is a new card', () async {
      await repository.addCard('u1', card('4242'));
      await repository.addCard('u1', card('4242', expYear: 2029));

      expect((await cardsOf('u1').get()).docs, hasLength(2));
    });

    test('a 6th card is refused', () async {
      for (final last4 in ['1111', '2222', '3333', '4444', '5555']) {
        await repository.addCard('u1', card(last4));
      }

      await expectLater(
        repository.addCard('u1', card('6666')),
        throwsA(const DataFailure('You can save up to 5 cards.')),
      );
      expect((await cardsOf('u1').get()).docs, hasLength(5));
    });

    test('each customer has their own cards', () async {
      await repository.addCard('u1', card('4242'));

      expect(await repository.watchCards('u2').first, isEmpty);
    });
  });

  group('watchCards', () {
    test('shows the default first, then the newest', () async {
      await addRaw('old', '1111', DateTime(2026, 10, 1));
      await addRaw('def', '2222', DateTime(2026, 10, 2), isDefault: true);
      await addRaw('new', '3333', DateTime(2026, 10, 3));

      final cards = await repository.watchCards('u1').first;

      expect(cards.map((c) => c.id), ['def', 'new', 'old']);
    });

    test('reads all fields correctly', () async {
      await addRaw('c1', '4242', DateTime(2026, 10, 1), isDefault: true);

      final saved = (await repository.watchCards('u1').first).single;

      expect(saved.brand, CardBrand.visa);
      expect(saved.holderName, 'Nimal Perera');
      expect(saved.expiryText, '08/28');
      expect(saved.createdAt, DateTime(2026, 10, 1));
    });
  });

  group('deleteCard', () {
    test('deleting a card that is not default changes nothing else',
        () async {
      await addRaw('def', '1111', DateTime(2026, 10, 1), isDefault: true);
      await addRaw('other', '2222', DateTime(2026, 10, 2));
      final cards = await repository.watchCards('u1').first;

      await repository.deleteCard('u1', cards.last);

      final left = await repository.watchCards('u1').first;
      expect(left.map((c) => c.id), ['def']);
      expect(left.single.isDefault, isTrue);
    });

    test('deleting the default makes the newest card left default',
        () async {
      await addRaw('def', '1111', DateTime(2026, 10, 1), isDefault: true);
      await addRaw('older', '2222', DateTime(2026, 10, 2));
      await addRaw('newest', '3333', DateTime(2026, 10, 3));
      final cards = await repository.watchCards('u1').first;

      await repository.deleteCard('u1', cards.first);

      final left = await repository.watchCards('u1').first;
      expect(left.map((c) => c.id), ['newest', 'older']);
      expect(left.first.isDefault, isTrue);
      expect(left.last.isDefault, isFalse);
    });

    test('deleting the only card leaves no cards', () async {
      await addRaw('def', '1111', DateTime(2026, 10, 1), isDefault: true);
      final cards = await repository.watchCards('u1').first;

      await repository.deleteCard('u1', cards.single);

      expect(await repository.watchCards('u1').first, isEmpty);
    });
  });

  group('setDefault', () {
    test('moves the default to the chosen card', () async {
      await addRaw('a', '1111', DateTime(2026, 10, 1), isDefault: true);
      await addRaw('b', '2222', DateTime(2026, 10, 2));

      await repository.setDefault('u1', 'b');

      final cards = await repository.watchCards('u1').first;
      expect(cards.map((c) => c.id), ['b', 'a']);
      expect(cards.where((c) => c.isDefault), hasLength(1));
    });
  });
}