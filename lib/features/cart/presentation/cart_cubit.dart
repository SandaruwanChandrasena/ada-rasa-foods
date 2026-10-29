import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../menu/domain/dish.dart';
import '../../menu/domain/menu_repository.dart';
import '../../restaurants/domain/restaurant.dart';
import '../../restaurants/domain/restaurant_repository.dart';
import '../domain/cart.dart';
import '../domain/cart_repository.dart';
import 'cart_state.dart';

// What happened when the customer tapped Add.
enum AddToCartResult { added, otherRestaurant, maxReached, noUser }

// One cart for the whole customer area (CUS-3, CUS-13).
// It also watches the cart's restaurant and menu live in Firestore.
class CartCubit extends Cubit<CartState> {
  CartCubit(
    this._repository,
    this._restaurantRepository,
    this._menuRepository, {
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        super(const CartState());

  final CartRepository _repository;
  final RestaurantRepository _restaurantRepository;
  final MenuRepository _menuRepository;

  // Tests can pass a fixed time here.
  final DateTime Function() _clock;

  StreamSubscription<Restaurant?>? _restaurantSub;
  StreamSubscription<List<Dish>>? _menuSub;
  String? _watchedRestaurantId;

  // Latest live menu of the cart's restaurant. Null until it arrives.
  List<Dish>? _menu;

  // Called when a customer signs in or out. Loads that user's saved cart.
  Future<void> setUser(String? userId) async {
    if (userId == state.userId) return;

    if (userId == null) {
      // The saved cart stays on the phone for the next sign in.
      emit(const CartState());
      _syncWatch();
      return;
    }

    emit(CartState(userId: userId, isLoading: true));
    _syncWatch();
    final cart = await _repository.loadCart(userId);

    // Stop if the user changed while we were loading.
    if (isClosed || state.userId != userId) return;
    emit(CartState(userId: userId, cart: cart));
    _syncWatch();
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

    final sameRestaurant = cart.restaurantId == state.cart.restaurantId;
    emit(
      state.copyWith(
        cart: cart,
        // A new restaurant starts again as "checking".
        restaurantStatus:
            sameRestaurant ? null : CartRestaurantStatus.checking,
        unavailableDishIds: sameRestaurant ? _unavailableIn(cart) : const {},
      ),
    );
    _syncWatch();
    unawaited(_save(userId, cart));
  }

  // Watches the restaurant only while the cart has food from it.
  void _syncWatch() {
    final cart = state.cart;
    final restaurantId = cart.isEmpty ? null : cart.restaurantId;
    if (restaurantId == _watchedRestaurantId) return;

    _stopWatching();
    _watchedRestaurantId = restaurantId;
    if (restaurantId == null) return;

    // On a stream error we keep the last known state.
    _restaurantSub = _restaurantRepository
        .watchRestaurant(restaurantId)
        .listen(_onRestaurant, onError: (Object _) {});
    _menuSub = _menuRepository
        .watchMenu(restaurantId)
        .listen(_onMenu, onError: (Object _) {});
  }

  void _stopWatching() {
    _restaurantSub?.cancel();
    _menuSub?.cancel();
    _restaurantSub = null;
    _menuSub = null;
    _watchedRestaurantId = null;
    _menu = null;
  }

  void _onRestaurant(Restaurant? restaurant) {
    final CartRestaurantStatus status;
    if (restaurant == null || !restaurant.isActive) {
      status = CartRestaurantStatus.unavailable;
    } else if (!restaurant.isOpen) {
      status = CartRestaurantStatus.closed;
    } else {
      status = CartRestaurantStatus.open;
    }

    final previous = state.restaurantStatus;
    if (status == previous) return;

    final name = state.cart.restaurantName;
    String? notice;
    if (status == CartRestaurantStatus.closed) {
      notice = '$name is closed now. You can order when it opens.';
    } else if (status == CartRestaurantStatus.unavailable) {
      notice = '$name is not available now. Please clear your cart.';
    } else if (previous == CartRestaurantStatus.closed) {
      notice = '$name is open again.';
    }

    _emitWithNotice(state.copyWith(restaurantStatus: status), notice);
  }

  void _onMenu(List<Dish> menu) {
    _menu = menu;
    final userId = state.userId;

    final cart = state.cart.withMenuDetails(menu);
    final unavailable = _unavailableIn(cart);
    final newlyGone = unavailable.difference(state.unavailableDishIds);

    String? notice;
    if (newlyGone.isNotEmpty) {
      final names = cart.items
          .where((item) => newlyGone.contains(item.dishId))
          .map((item) => item.name)
          .join(', ');
      notice = newlyGone.length == 1
          ? '$names is not available now. '
              'Remove it from your cart to checkout.'
          : '$names are not available now. '
              'Remove them from your cart to checkout.';
    }

    final priceChanged = cart != state.cart;
    _emitWithNotice(
      state.copyWith(cart: cart, unavailableDishIds: unavailable),
      notice,
    );
    if (priceChanged && userId != null) unawaited(_save(userId, cart));
  }

  // Cart dishes that are gone from the menu or marked not available.
  Set<String> _unavailableIn(Cart cart) {
    final menu = _menu;
    if (menu == null) return const {};

    final availableIds = {
      for (final dish in menu)
        if (dish.available) dish.id,
    };
    return {
      for (final item in cart.items)
        if (!availableIds.contains(item.dishId)) item.dishId,
    };
  }

  void _emitWithNotice(CartState next, String? notice) {
    if (notice == null) {
      emit(next);
    } else {
      emit(next.copyWith(notice: notice, noticeId: state.noticeId + 1));
    }
  }

  Future<void> _save(String userId, Cart cart) async {
    try {
      await _repository.saveCart(userId, cart);
    } catch (_) {
      // The cart still works now. It is only not kept after a restart.
    }
  }

  @override
  Future<void> close() async {
    await _restaurantSub?.cancel();
    await _menuSub?.cancel();
    return super.close();
  }
}