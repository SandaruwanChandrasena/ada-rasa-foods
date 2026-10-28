import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/data_failure.dart';
import '../../menu/domain/dish.dart';
import '../../menu/domain/menu_repository.dart';
import '../domain/restaurant.dart';
import '../domain/restaurant_repository.dart';
import 'restaurant_detail_state.dart';

// Restaurant page: one restaurant and its menu, both live (CUS-2).
class RestaurantDetailCubit extends Cubit<RestaurantDetailState> {
  RestaurantDetailCubit(this._restaurantRepository, this._menuRepository)
      : super(const RestaurantDetailState());

  final RestaurantRepository _restaurantRepository;
  final MenuRepository _menuRepository;

  StreamSubscription<Restaurant?>? _restaurantSub;
  StreamSubscription<List<Dish>>? _menuSub;

  // Latest data from each stream.
  Restaurant? _restaurant;
  List<Dish> _dishes = const [];
  bool _restaurantArrived = false;
  bool _menuArrived = false;

  // Starts (or restarts) watching. The Retry button also calls this.
  void start(String restaurantId) {
    _cancelStreams();
    _restaurant = null;
    _dishes = const [];
    _restaurantArrived = false;
    _menuArrived = false;
    emit(const RestaurantDetailState());

    _restaurantSub = _restaurantRepository.watchRestaurant(restaurantId).listen(
      (restaurant) {
        _restaurant = restaurant;
        _restaurantArrived = true;
        _update();
      },
      onError: _onError,
    );

    _menuSub = _menuRepository.watchMenu(restaurantId).listen(
      (dishes) {
        _dishes = dishes;
        _menuArrived = true;
        _update();
      },
      onError: _onError,
    );
  }

  void _update() {
    // Wait for the restaurant first. A missing one needs no menu.
    if (!_restaurantArrived) return;

    final restaurant = _restaurant;
    // A deleted or turned-off restaurant is not shown to customers.
    if (restaurant == null || !restaurant.isActive) {
      emit(const RestaurantDetailState(
        status: RestaurantDetailStatus.notFound,
      ));
      return;
    }

    // Show the page only when the menu has also arrived.
    if (!_menuArrived) return;

    emit(RestaurantDetailState(
      status: RestaurantDetailStatus.loaded,
      restaurant: restaurant,
      dishes: _dishes,
    ));
  }

  void _onError(Object error) {
    final message = error is DataFailure
        ? error.message
        : 'Something went wrong. Please try again.';
    emit(RestaurantDetailState(
      status: RestaurantDetailStatus.failure,
      errorMessage: message,
    ));
  }

  void _cancelStreams() {
    _restaurantSub?.cancel();
    _menuSub?.cancel();
  }

  @override
  Future<void> close() async {
    await _restaurantSub?.cancel();
    await _menuSub?.cancel();
    return super.close();
  }
}