import 'package:equatable/equatable.dart';

import '../domain/dish.dart';

enum MenuView { loading, loaded, failure }

// The owner's menu (RES-3).
class MenuManageState extends Equatable {
  const MenuManageState({
    this.view = MenuView.loading,
    this.dishes = const [],
    this.busyIds = const {},
    this.errorMessage,
    this.notice,
    this.noticeId = 0,
  });

  final MenuView view;

  // Grouped by category, then A to Z (the repository sorts them).
  final List<Dish> dishes;

  // Dishes whose Available switch is saving now.
  final Set<String> busyIds;

  // Why the menu could not be loaded.
  final String? errorMessage;

  // A message for the owner. A new noticeId means "show it now".
  final String? notice;
  final int noticeId;

  // Categories in menu order, each once. The dish form shows them as chips.
  List<String> get categories {
    final seen = <String>[];
    for (final dish in dishes) {
      if (!seen.contains(dish.category)) seen.add(dish.category);
    }
    return seen;
  }

  List<Dish> dishesIn(String category) =>
      dishes.where((dish) => dish.category == category).toList();

  bool isBusy(Dish dish) => busyIds.contains(dish.id);

  MenuManageState copyWith({
    MenuView? view,
    List<Dish>? dishes,
    Set<String>? busyIds,
    String? notice,
    int? noticeId,
  }) {
    return MenuManageState(
      view: view ?? this.view,
      dishes: dishes ?? this.dishes,
      busyIds: busyIds ?? this.busyIds,
      errorMessage: errorMessage,
      notice: notice ?? this.notice,
      noticeId: noticeId ?? this.noticeId,
    );
  }

  @override
  List<Object?> get props => [
        view,
        dishes,
        // A sorted list, so two sets with the same ids are equal.
        busyIds.toList()..sort(),
        errorMessage,
        notice,
        noticeId,
      ];
}