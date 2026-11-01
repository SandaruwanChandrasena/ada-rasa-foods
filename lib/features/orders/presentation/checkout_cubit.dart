import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/data_failure.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/phone_checks.dart';
import '../../cart/presentation/cart_state.dart';
import '../../payments/domain/payment_card.dart';
import '../../restaurants/domain/restaurant_repository.dart';
import '../domain/food_order.dart';
import '../domain/order_repository.dart';
import '../domain/order_status.dart';
import 'checkout_state.dart';

// Places the order from the cart (CUS-4).
// No card means cash. A card order is saved only after the demo payment
// was approved, so it is saved as paid.
class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(this._orderRepository, this._restaurantRepository)
      : super(const CheckoutState());

  static const declinedMessage =
      'Your card was declined (demo). No order was placed.';

  static const phoneNeededMessage =
      'Please add your phone number, so the restaurant can call you.';

  final OrderRepository _orderRepository;
  final RestaurantRepository _restaurantRepository;

  Future<void> placeOrder({
    required AppUser user,
    required CartState cart,
    PaymentCard? card,
  }) async {
    // A second tap must never place a second order.
    if (state.isPlacing || state.status == CheckoutStatus.placed) return;

    if (!cart.canCheckout) {
      emit(
        const CheckoutState(
          status: CheckoutStatus.failure,
          errorMessage: 'Your cart cannot be ordered right now.',
        ),
      );
      return;
    }

    // The restaurant must be able to call. The rules check this too.
    if (!PhoneChecks.isValid(user.phone)) {
      emit(
        const CheckoutState(
          status: CheckoutStatus.failure,
          errorMessage: phoneNeededMessage,
        ),
      );
      return;
    }

    // Safety net: the 0002 card must never be saved as paid.
    if (card != null && card.alwaysFails) {
      emit(
        const CheckoutState(
          status: CheckoutStatus.failure,
          errorMessage: declinedMessage,
        ),
      );
      return;
    }

    emit(const CheckoutState(status: CheckoutStatus.placing));

    try {
      // One last check, and we need the address for the order.
      final restaurant = await _restaurantRepository
          .watchRestaurant(cart.cart.restaurantId)
          .first;
      if (restaurant == null || !restaurant.canTakeOrders) {
        throw DataFailure(
          '${cart.cart.restaurantName} is not taking orders now.',
        );
      }

      final order = FoodOrder.fromCart(
        cart: cart.cart,
        customerId: user.uid,
        customerName: user.name,
        customerPhone: PhoneChecks.digitsOnly(user.phone),
        restaurantAddress: restaurant.address,
        paymentMethod:
            card == null ? PaymentMethod.cash : PaymentMethod.card,
        cardBrand: card?.brand.name ?? '',
        cardLast4: card?.last4 ?? '',
      );
      final orderId = await _orderRepository.placeOrder(order);

      // The customer may leave the screen while we wait.
      if (isClosed) return;
      emit(CheckoutState(status: CheckoutStatus.placed, orderId: orderId));
    } catch (error) {
      if (isClosed) return;
      emit(
        CheckoutState(
          status: CheckoutStatus.failure,
          errorMessage: error is DataFailure
              ? error.message
              : 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  // Back to ready after a failure, for "Try another card".
  void reset() {
    if (state.status != CheckoutStatus.failure) return;
    emit(const CheckoutState());
  }
}