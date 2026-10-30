import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/payments/domain/card_brand.dart';
import 'package:ada_rasa_foods/features/payments/domain/card_repository.dart';
import 'package:ada_rasa_foods/features/payments/domain/payment_card.dart';
import 'package:ada_rasa_foods/features/payments/presentation/cards_cubit.dart';
import 'package:ada_rasa_foods/features/payments/presentation/cards_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCardRepository extends Mock implements CardRepository {}

PaymentCard saved(
  String id,
  String last4, {
  bool isDefault = false,
  int expMonth = 8,
  int expYear = 2028,
}) {
  return PaymentCard(
    id: id,
    brand: CardBrand.visa,
    last4: last4,
    holderName: 'Nimal Perera',
    expMonth: expMonth,
    expYear: expYear,
    isDefault: isDefault,
  );
}

// Lets stream events reach the cubit.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late MockCardRepository repository;
  late StreamController<List<PaymentCard>> cardStream;
  late CardsCubit cubit;

  final now = DateTime(2026, 10, 30);
  final visa = saved('c1', '4242', isDefault: true);
  final master = saved('c2', '4444');

  setUpAll(() => registerFallbackValue(saved('x', '0000')));

  setUp(() {
    repository = MockCardRepository();
    cardStream = StreamController<List<PaymentCard>>.broadcast();
    when(() => repository.watchCards('u1'))
        .thenAnswer((_) => cardStream.stream);
    when(() => repository.addCard(any(), any())).thenAnswer((_) async {});
    when(() => repository.deleteCard(any(), any()))
        .thenAnswer((_) async {});
    when(() => repository.setDefault(any(), any()))
        .thenAnswer((_) async {});

    cubit = CardsCubit(repository, clock: () => now);
  });

  tearDown(() async {
    await cubit.close();
    await cardStream.close();
  });

  Future<void> startWith(List<PaymentCard> cards) async {
    cubit.start('u1');
    cardStream.add(cards);
    await settle();
  }

  Future<bool> addGoodVisa() => cubit.addCard(
        number: '4242 4242 4242 4242',
        name: '  Nimal Perera  ',
        expiry: '08/28',
        cvv: '123',
      );

  group('loading', () {
    test('starts loading with no cards', () {
      expect(cubit.state, const CardsState());
    });

    test('shows the cards when they arrive', () async {
      await startWith([visa, master]);

      expect(cubit.state.status, CardsStatus.loaded);
      expect(cubit.state.cards, [visa, master]);
    });

    test('shows the error message when loading fails', () async {
      cubit.start('u1');
      cardStream.addError(const DataFailure('No internet connection.'));
      await settle();

      expect(cubit.state.status, CardsStatus.failure);
      expect(cubit.state.errorMessage, 'No internet connection.');
    });

    test('Retry loads the cards again', () async {
      cubit.start('u1');
      cardStream.addError(const DataFailure('No internet connection.'));
      await settle();

      cubit.retry();
      cardStream.add([visa]);
      await settle();

      expect(cubit.state.status, CardsStatus.loaded);
      verify(() => repository.watchCards('u1')).called(2);
    });
  });

  group('usableDefault', () {
    test('gives the default card', () async {
      await startWith([visa, master]);

      expect(cubit.state.usableDefault(now), visa);
    });

    test('gives null when the default card has expired', () async {
      final old = saved('c1', '4242', isDefault: true, expYear: 2025);
      await startWith([old, master]);

      expect(cubit.state.usableDefault(now), isNull);
    });

    test('gives null when there are no cards', () async {
      await startWith([]);

      expect(cubit.state.usableDefault(now), isNull);
    });
  });

  group('addCard', () {
    test('saves only the type, last 4, name, and expiry', () async {
      await startWith([]);

      final ok = await addGoodVisa();

      expect(ok, isTrue);
      final card = verify(() => repository.addCard('u1', captureAny()))
          .captured
          .single as PaymentCard;
      expect(card.brand, CardBrand.visa);
      expect(card.last4, '4242');
      expect(card.holderName, 'Nimal Perera');
      expect(card.expMonth, 8);
      expect(card.expYear, 2028);
      expect(cubit.state.notice, 'Card saved.');
      expect(cubit.state.isWorking, isFalse);
    });

    test('a Mastercard gets the Mastercard type', () async {
      await startWith([]);

      await cubit.addCard(
        number: '5555 5555 5555 4444',
        name: 'Nimal Perera',
        expiry: '01/27',
        cvv: '999',
      );

      final card = verify(() => repository.addCard('u1', captureAny()))
          .captured
          .single as PaymentCard;
      expect(card.brand, CardBrand.mastercard);
      expect(card.last4, '4444');
    });

    test('a bad number is not saved and shows why', () async {
      await startWith([]);

      final ok = await cubit.addCard(
        number: '4242 4242 4242 4241',
        name: 'Nimal Perera',
        expiry: '08/28',
        cvv: '123',
      );

      expect(ok, isFalse);
      expect(cubit.state.notice, 'This card number is not valid.');
      verifyNever(() => repository.addCard(any(), any()));
    });

    test('an expired card is not saved', () async {
      await startWith([]);

      final ok = await cubit.addCard(
        number: '4242 4242 4242 4242',
        name: 'Nimal Perera',
        expiry: '09/26',
        cvv: '123',
      );

      expect(ok, isFalse);
      expect(cubit.state.notice, 'This card has expired.');
      verifyNever(() => repository.addCard(any(), any()));
    });

    test('a bad CVV is not saved', () async {
      await startWith([]);

      final ok = await cubit.addCard(
        number: '4242 4242 4242 4242',
        name: 'Nimal Perera',
        expiry: '08/28',
        cvv: '12',
      );

      expect(ok, isFalse);
      expect(cubit.state.notice, 'The CVV must have 3 digits.');
    });

    test('shows the reason when saving fails', () async {
      when(() => repository.addCard(any(), any())).thenThrow(
        const DataFailure('This card is already saved.'),
      );
      await startWith([visa]);

      final ok = await addGoodVisa();

      expect(ok, isFalse);
      expect(cubit.state.notice, 'This card is already saved.');
      expect(cubit.state.isWorking, isFalse);
    });

    test('a fast second tap saves only once', () async {
      await startWith([]);

      final first = addGoodVisa();
      final second = await addGoodVisa();
      await first;

      expect(second, isFalse);
      verify(() => repository.addCard(any(), any())).called(1);
    });
  });

  group('deleteCard and setDefault', () {
    test('deleteCard deletes and shows a message', () async {
      await startWith([visa, master]);

      final ok = await cubit.deleteCard(master);

      expect(ok, isTrue);
      verify(() => repository.deleteCard('u1', master)).called(1);
      expect(cubit.state.notice, 'Visa ending 4444 deleted.');
    });

    test('deleteCard shows the reason when it fails', () async {
      when(() => repository.deleteCard(any(), any())).thenThrow(
        const DataFailure('No internet connection. Please try again.'),
      );
      await startWith([visa]);

      final ok = await cubit.deleteCard(visa);

      expect(ok, isFalse);
      expect(
        cubit.state.notice,
        'No internet connection. Please try again.',
      );
    });

    test('setDefault moves the default and shows a message', () async {
      await startWith([visa, master]);

      final ok = await cubit.setDefault(master);

      expect(ok, isTrue);
      verify(() => repository.setDefault('u1', 'c2')).called(1);
      expect(
        cubit.state.notice,
        'Visa ending 4444 is now your default card.',
      );
    });

    test('setDefault does nothing for the card that is default', () async {
      await startWith([visa, master]);

      final ok = await cubit.setDefault(visa);

      expect(ok, isFalse);
      verifyNever(() => repository.setDefault(any(), any()));
    });
  });
}