import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/data_failure.dart';
import '../domain/card_checks.dart';
import '../domain/card_repository.dart';
import '../domain/payment_card.dart';
import 'cards_state.dart';

// My cards: list, add, delete, and set the default card (CUS-9).
class CardsCubit extends Cubit<CardsState> {
  CardsCubit(this._cardRepository, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(const CardsState());

  final CardRepository _cardRepository;

  // Tests can pass a fixed time here.
  final DateTime Function() _clock;

  StreamSubscription<List<PaymentCard>>? _subscription;
  String? _userId;

  DateTime get now => _clock();

  // Starts (or restarts) watching this customer's cards.
  void start(String userId) {
    _userId = userId;
    _subscription?.cancel();
    emit(const CardsState());

    _subscription = _cardRepository.watchCards(userId).listen(
      (cards) => emit(
        state.copyWith(status: CardsStatus.loaded, cards: cards),
      ),
      onError: (Object error) => emit(
        CardsState(
          status: CardsStatus.failure,
          errorMessage: _message(error),
        ),
      ),
    );
  }

  void retry() {
    final userId = _userId;
    if (userId != null) start(userId);
  }

  // Gives true when the card is saved. The CVV is checked, never saved.
  Future<bool> addCard({
    required String number,
    required String name,
    required String expiry,
    required String cvv,
  }) async {
    final userId = _userId;
    if (userId == null || state.isWorking) return false;

    // The form checks too. This is the last safety check.
    final error = CardChecks.numberError(number) ??
        CardChecks.nameError(name) ??
        CardChecks.expiryError(expiry, now) ??
        CardChecks.cvvError(cvv);
    final brand = CardChecks.brandOf(number);
    final parsedExpiry = CardChecks.parseExpiry(expiry);
    if (error != null || brand == null || parsedExpiry == null) {
      _notify(error ?? 'Please check the card details.');
      return false;
    }

    final (month, year) = parsedExpiry;
    final card = PaymentCard(
      brand: brand,
      last4: CardChecks.last4Of(number),
      holderName: name.trim(),
      expMonth: month,
      expYear: year,
    );

    return _run(
      () => _cardRepository.addCard(userId, card),
      success: 'Card saved.',
    );
  }

  Future<bool> deleteCard(PaymentCard card) async {
    final userId = _userId;
    if (userId == null || state.isWorking) return false;

    return _run(
      () => _cardRepository.deleteCard(userId, card),
      success: '${card.title} deleted.',
    );
  }

  Future<bool> setDefault(PaymentCard card) async {
    final userId = _userId;
    if (userId == null || state.isWorking || card.isDefault) return false;

    return _run(
      () => _cardRepository.setDefault(userId, card.id),
      success: '${card.title} is now your default card.',
    );
  }

  // Runs one change. A second tap waits until this one ends.
  Future<bool> _run(
    Future<void> Function() action, {
    required String success,
  }) async {
    emit(state.copyWith(isWorking: true));

    String message;
    var ok = false;
    try {
      await action();
      message = success;
      ok = true;
    } catch (error) {
      message = _message(error);
    }

    if (isClosed) return ok;
    emit(state.copyWith(isWorking: false));
    _notify(message);
    return ok;
  }

  void _notify(String message) {
    if (isClosed) return;
    emit(state.copyWith(notice: message, noticeId: state.noticeId + 1));
  }

  String _message(Object error) => error is DataFailure
      ? error.message
      : 'Something went wrong. Please try again.';

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}