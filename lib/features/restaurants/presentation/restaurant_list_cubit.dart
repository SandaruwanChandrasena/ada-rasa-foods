import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/data_failure.dart';
import '../domain/restaurant.dart';
import '../domain/restaurant_repository.dart';
import 'restaurant_list_state.dart';

// Customer home list: live restaurants, search, and cuisine chips (CUS-1).
class RestaurantListCubit extends Cubit<RestaurantListState> {
  RestaurantListCubit(this._repository) : super(const RestaurantListState());

  final RestaurantRepository _repository;
  StreamSubscription<List<Restaurant>>? _subscription;

  // Starts (or restarts) watching. The Retry button also calls this.
  void start() {
    _subscription?.cancel();
    emit(state.copyWith(
      status: RestaurantListStatus.loading,
      errorMessage: () => null,
    ));

    _subscription = _repository.watchActiveRestaurants().listen(
      _onRestaurants,
      onError: (Object error) {
        final message = error is DataFailure
            ? error.message
            : 'Something went wrong. Please try again.';
        emit(state.copyWith(
          status: RestaurantListStatus.failure,
          errorMessage: () => message,
        ));
      },
    );
  }

  void _onRestaurants(List<Restaurant> restaurants) {
    final selected = state.selectedCuisine;
    final stillExists =
        selected == null || restaurants.any((r) => r.cuisine.trim() == selected);

    emit(state.copyWith(
      status: RestaurantListStatus.loaded,
      restaurants: restaurants,
      // If the chosen cuisine is gone, go back to "All".
      selectedCuisine: stillExists ? null : () => null,
      errorMessage: () => null,
    ));
  }

  void search(String text) {
    emit(state.copyWith(searchText: text));
  }

  // Pass null to choose "All".
  void selectCuisine(String? cuisine) {
    emit(state.copyWith(selectedCuisine: () => cuisine));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}