import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/data_failure.dart';
import '../domain/dish.dart';
import '../domain/menu_repository.dart';
import 'menu_manage_state.dart';

// The owner's menu, live, with the Available switch (RES-3).
class MenuManageCubit extends Cubit<MenuManageState> {
  MenuManageCubit(this._repository) : super(const MenuManageState());

  final MenuRepository _repository;

  StreamSubscription<List<Dish>>? _subscription;
  String? _restaurantId;

  // Starts (or restarts) watching. The Retry button also calls this.
  Future<void> start(String restaurantId) async {
    _restaurantId = restaurantId;
    await _subscription?.cancel();
    emit(const MenuManageState());

    _subscription = _repository.watchMenu(restaurantId).listen(
      (dishes) => emit(state.copyWith(view: MenuView.loaded, dishes: dishes)),
      onError: (Object error) {
        emit(
          MenuManageState(
            view: MenuView.failure,
            errorMessage: error is DataFailure
                ? error.message
                : 'Something went wrong. Please try again.',
          ),
        );
      },
    );
  }

  void retry() {
    final restaurantId = _restaurantId;
    if (restaurantId != null) start(restaurantId);
  }

  Future<void> setAvailable(Dish dish, {required bool available}) async {
    if (state.isBusy(dish) || dish.available == available) return;
    emit(state.copyWith(busyIds: {...state.busyIds, dish.id}));

    String message;
    try {
      await _repository.setAvailable(dish, available: available);
      message = available
          ? '${dish.name} is now available.'
          : '${dish.name} is hidden from customers.';
    } catch (error) {
      message = error is DataFailure
          ? error.message
          : 'Something went wrong. Please try again.';
    }

    if (isClosed) return;
    // The live list shows the new switch. Here we only show a message.
    emit(
      state.copyWith(
        busyIds: {...state.busyIds}..remove(dish.id),
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