import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/data_failure.dart';
import '../../auth/domain/app_user.dart';
import '../../cart/presentation/cart_state.dart';
import '../../restaurants/domain/restaurant_repository.dart';
import '../domain/food_order.dart';
import '../domain/order_repository.dart';
import '../domain/order_status.dart';
import 'checkout_state.dart';

// Places the order from the cart (CUS-4). Cash only for now.
class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(this._orderRepository, this._restaurantRepository)
      : super(const CheckoutState());

  final OrderRepository _orderRepository;
  final RestaurantRepository _restaurantRepository;

  Future<void> placeOrder({
    required AppUser user,
    required CartState cart,
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
        restaurantAddress: restaurant.address,
        paymentMethod: PaymentMethod.cash,
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
}