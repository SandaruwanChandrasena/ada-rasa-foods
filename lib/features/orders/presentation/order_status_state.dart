import 'package:equatable/equatable.dart';

import '../domain/food_order.dart';

// Called OrderView, so it never mixes up with OrderStatus.
enum OrderView { loading, loaded, notFound, failure }

class OrderStatusState extends Equatable {
  const OrderStatusState({
    this.view = OrderView.loading,
    this.order,
    this.errorMessage,
    this.isCancelling = false,
    this.notice,
    this.noticeId = 0,
  });

  final OrderView view;
  final FoodOrder? order;

  // Why the order could not be loaded.
  final String? errorMessage;

  final bool isCancelling;

  // A message for the customer. A new noticeId means "show it now".
  final String? notice;
  final int noticeId;

  bool get canCancel =>
      view == OrderView.loaded && (order?.canCancel ?? false) && !isCancelling;

  OrderStatusState copyWith({
    OrderView? view,
    FoodOrder? order,
    bool? isCancelling,
    String? notice,
    int? noticeId,
  }) {
    return OrderStatusState(
      view: view ?? this.view,
      order: order ?? this.order,
      errorMessage: errorMessage,
      isCancelling: isCancelling ?? this.isCancelling,
      notice: notice ?? this.notice,
      noticeId: noticeId ?? this.noticeId,
    );
  }

  @override
  List<Object?> get props => [
        view,
        order,
        errorMessage,
        isCancelling,
        notice,
        noticeId,
      ];
}