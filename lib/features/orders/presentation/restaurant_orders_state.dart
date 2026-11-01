import 'package:equatable/equatable.dart';

import '../domain/food_order.dart';
import '../domain/order_status.dart';

enum BoardView { loading, loaded, failure }

// The restaurant orders board (RES-1).
class RestaurantOrdersState extends Equatable {
  const RestaurantOrdersState({
    this.view = BoardView.loading,
    this.open = const [],
    this.done = const [],
    this.doneLoaded = false,
    this.busyIds = const {},
    this.errorMessage,
    this.notice,
    this.noticeId = 0,
    this.newOrderNumber,
    this.newOrderAlertId = 0,
  });

  final BoardView view;

  // Placed, accepted, preparing, ready. Oldest first.
  final List<FoodOrder> open;

  // Completed, rejected, cancelled. Newest first.
  final List<FoodOrder> done;
  final bool doneLoaded;

  // Orders being saved now. Their buttons show a spinner.
  final Set<String> busyIds;

  // Why the orders could not be loaded.
  final String? errorMessage;

  // A message for the owner. A new noticeId means "show it now".
  final String? notice;
  final int noticeId;

  // A new order arrived. A new alert id means "vibrate and show it".
  final String? newOrderNumber;
  final int newOrderAlertId;

  // New tab.
  List<FoodOrder> get newOrders =>
      open.where((o) => o.status == OrderStatus.placed).toList();

  // Active tab.
  List<FoodOrder> get activeOrders =>
      open.where((o) => o.status != OrderStatus.placed).toList();

  bool isBusy(FoodOrder order) => busyIds.contains(order.id);

  RestaurantOrdersState copyWith({
    BoardView? view,
    List<FoodOrder>? open,
    List<FoodOrder>? done,
    bool? doneLoaded,
    Set<String>? busyIds,
    String? notice,
    int? noticeId,
    String? newOrderNumber,
    int? newOrderAlertId,
  }) {
    return RestaurantOrdersState(
      view: view ?? this.view,
      open: open ?? this.open,
      done: done ?? this.done,
      doneLoaded: doneLoaded ?? this.doneLoaded,
      busyIds: busyIds ?? this.busyIds,
      errorMessage: errorMessage,
      notice: notice ?? this.notice,
      noticeId: noticeId ?? this.noticeId,
      newOrderNumber: newOrderNumber ?? this.newOrderNumber,
      newOrderAlertId: newOrderAlertId ?? this.newOrderAlertId,
    );
  }

  @override
  List<Object?> get props => [
        view,
        open,
        done,
        doneLoaded,
        // A sorted list, so two sets with the same ids are equal.
        busyIds.toList()..sort(),
        errorMessage,
        notice,
        noticeId,
        newOrderNumber,
        newOrderAlertId,
      ];
}