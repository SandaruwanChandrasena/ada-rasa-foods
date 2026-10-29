import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../menu/domain/dish.dart';
import '../domain/cart.dart';
import '../domain/cart_repository.dart';
import 'cart_state.dart';

// What happened when the customer tapped Add.
enum AddToCartResult { added, otherRestaurant, maxReached, noUser }

// One cart for the whole customer area (CUS-3, CUS-13).
class CartCubit extends Cubit<CartState> {
  CartCubit(this._repository, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(const CartState());

  final CartRepository _repository;

  // Tests can pass a fixed time here.
  final DateTime Function() _clock;

  // Called when a customer signs in or out. Loads that user's saved cart.
  Future<void> setUser(String? userId) async {
    if (userId == state.userId) return;

    if (userId == null) {
      // The saved cart stays on the phone for the next sign in.
      emit(const CartState());
      return;
    }

    emit(CartState(userId: userId, isLoading: true));
    final cart = await _repository.loadCart(userId);

    // Stop if the user changed while we were loading.
    if (isClosed || state.userId != userId) return;
    emit(CartState(userId: userId, cart: cart));
  }

  // The UI shows the "Clear cart?" dialog for otherRestaurant.
  AddToCartResult addDish(Dish dish, {required String restaurantName}) {
    if (state.userId == null) return AddToCartResult.noUser;

    final cart = _freshCart();
    if (cart.isFromOtherRestaurant(dish.restaurantId)) {
      return AddToCartResult.otherRestaurant;
    }
    if (!cart.canAddMore(dish.id)) return AddToCartResult.maxReached;

    _update(cart.addDish(dish, restaurantName: restaurantName, now: _clock()));
    return AddToCartResult.added;
  }

  // Yes on "Clear cart and add this item?" (CUS-13).
  void clearAndAdd(Dish dish, {required String restaurantName}) {
    _update(
      Cart.empty.addDish(dish, restaurantName: restaurantName, now: _clock()),
    );
  }

  void increase(String dishId) {
    final cart = _freshCart();
    _update(
      cart.setQuantity(dishId, cart.quantityOf(dishId) + 1, now: _clock()),
    );
  }

  void decrease(String dishId) {
    final cart = _freshCart();
    _update(
      cart.setQuantity(dishId, cart.quantityOf(dishId) - 1, now: _clock()),
    );
  }

  void remove(String dishId) {
    _update(_freshCart().setQuantity(dishId, 0, now: _clock()));
  }

  void clear() => _update(Cart.empty);

  // A cart left open for more than 1 day starts again empty.
  Cart _freshCart() {
    final cart = state.cart;
    if (!cart.isEmpty && cart.isExpired(_clock())) return Cart.empty;
    return cart;
  }

  // Shows the change at once, then saves it on the phone.
  void _update(Cart cart) {
    final userId = state.userId;
    if (userId == null || cart == state.cart) return;

    emit(state.copyWith(cart: cart));
    unawaited(_save(userId, cart));
  }

  Future<void> _save(String userId, Cart cart) async {
    try {
      await _repository.saveCart(userId, cart);
    } catch (_) {
      // The cart still works now. It is only not kept after a restart.
    }
  }
}