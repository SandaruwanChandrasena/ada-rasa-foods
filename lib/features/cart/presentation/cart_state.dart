import 'package:equatable/equatable.dart';

import '../domain/cart.dart';

// Live state of the cart's restaurant.
enum CartRestaurantStatus { checking, open, closed, unavailable }

class CartState extends Equatable {
  const CartState({
    this.userId,
    this.cart = Cart.empty,
    this.isLoading = false,
    this.restaurantStatus = CartRestaurantStatus.checking,
    this.unavailableDishIds = const {},
    this.notice,
    this.noticeId = 0,
  });

  // The signed-in customer. Null means no cart (signed out or not a customer).
  final String? userId;

  final Cart cart;

  // True while the saved cart is read from the phone.
  final bool isLoading;

  final CartRestaurantStatus restaurantStatus;

  // Dishes in the cart that are not available now (from the live menu).
  final Set<String> unavailableDishIds;

  // A message for the customer. A new noticeId means "show it now".
  final String? notice;
  final int noticeId;

  bool isDishAvailable(String dishId) =>
      restaurantStatus != CartRestaurantStatus.unavailable &&
      !unavailableDishIds.contains(dishId);

  bool get hasUnavailableDishes => cart.items.any(
        (item) => !isDishAvailable(item.dishId),
      );

  // Badge and total count only dishes that can be ordered.
  int get itemCount => restaurantStatus == CartRestaurantStatus.unavailable
      ? 0
      : cart.itemCountWithout(unavailableDishIds);

  int get total => restaurantStatus == CartRestaurantStatus.unavailable
      ? 0
      : cart.totalWithout(unavailableDishIds);

  bool get canCheckout =>
      !cart.isEmpty &&
      restaurantStatus == CartRestaurantStatus.open &&
      !hasUnavailableDishes;

  CartState copyWith({
    Cart? cart,
    CartRestaurantStatus? restaurantStatus,
    Set<String>? unavailableDishIds,
    String? notice,
    int? noticeId,
  }) {
    return CartState(
      userId: userId,
      cart: cart ?? this.cart,
      isLoading: isLoading,
      restaurantStatus: restaurantStatus ?? this.restaurantStatus,
      unavailableDishIds: unavailableDishIds ?? this.unavailableDishIds,
      notice: notice ?? this.notice,
      noticeId: noticeId ?? this.noticeId,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        cart,
        isLoading,
        restaurantStatus,
        // A sorted list, so two sets with the same ids are equal.
        unavailableDishIds.toList()..sort(),
        notice,
        noticeId,
      ];
}