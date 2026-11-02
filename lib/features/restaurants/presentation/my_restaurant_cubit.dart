import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/data_failure.dart';
import '../domain/restaurant.dart';
import '../domain/restaurant_repository.dart';

enum MyRestaurantView { loading, loaded, notFound, failure }

// The owner's own restaurant: its name and the Open switch (RES-4).
class MyRestaurantState extends Equatable {
  const MyRestaurantState({
    this.view = MyRestaurantView.loading,
    this.restaurant,
    this.isSaving = false,
    this.notice,
    this.noticeId = 0,
  });

  final MyRestaurantView view;
  final Restaurant? restaurant;

  // True while the switch is saving. The switch is locked.
  final bool isSaving;

  // A message for the owner. A new noticeId means "show it now".
  final String? notice;
  final int noticeId;

  bool get canSwitch =>
      view == MyRestaurantView.loaded && restaurant != null && !isSaving;

  MyRestaurantState copyWith({
    MyRestaurantView? view,
    Restaurant? restaurant,
    bool? isSaving,
    String? notice,
    int? noticeId,
  }) {
    return MyRestaurantState(
      view: view ?? this.view,
      restaurant: restaurant ?? this.restaurant,
      isSaving: isSaving ?? this.isSaving,
      notice: notice ?? this.notice,
      noticeId: noticeId ?? this.noticeId,
    );
  }

  @override
  List<Object?> get props => [view, restaurant, isSaving, notice, noticeId];
}

// Kept in one file with its state, so this part stays small.
class MyRestaurantCubit extends Cubit<MyRestaurantState> {
  MyRestaurantCubit(this._repository) : super(const MyRestaurantState());

  final RestaurantRepository _repository;

  StreamSubscription<Restaurant?>? _subscription;
  String? _restaurantId;

  Future<void> start(String restaurantId) async {
    _restaurantId = restaurantId;
    await _subscription?.cancel();
    emit(const MyRestaurantState());

    _subscription = _repository.watchRestaurant(restaurantId).listen(
      (restaurant) {
        emit(
          restaurant == null
              ? state.copyWith(view: MyRestaurantView.notFound)
              : state.copyWith(
                  view: MyRestaurantView.loaded,
                  restaurant: restaurant,
                ),
        );
      },
      onError: (Object error) {
        emit(state.copyWith(view: MyRestaurantView.failure));
      },
    );
  }

  void retry() {
    final restaurantId = _restaurantId;
    if (restaurantId != null) start(restaurantId);
  }

  Future<void> setOpen(bool isOpen) async {
    final restaurant = state.restaurant;
    if (!state.canSwitch || restaurant == null) return;
    if (restaurant.isOpen == isOpen) return;

    emit(state.copyWith(isSaving: true));

    String message;
    try {
      await _repository.setOpen(restaurant.id, isOpen: isOpen);
      message = isOpen
          ? 'Your restaurant is open. Customers can order now.'
          : 'Your restaurant is closed. Customers cannot order.';
    } catch (error) {
      message = error is DataFailure
          ? error.message
          : 'Something went wrong. Please try again.';
    }

    if (isClosed) return;
    // The live stream shows the new switch. Here we only show a message.
    emit(
      state.copyWith(
        isSaving: false,
        notice: message,
        noticeId: state.noticeId + 1,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}