import 'package:equatable/equatable.dart';

import '../../menu/domain/dish.dart';
import '../domain/restaurant.dart';

enum RestaurantDetailStatus { loading, loaded, notFound, failure }

class RestaurantDetailState extends Equatable {
  const RestaurantDetailState({
    this.status = RestaurantDetailStatus.loading,
    this.restaurant,
    this.dishes = const [],
    this.errorMessage,
  });

  final RestaurantDetailStatus status;
  final Restaurant? restaurant;

  // Already sorted by category, then by name (MenuRepository does this).
  final List<Dish> dishes;

  final String? errorMessage;

  // Dishes grouped under each category heading, in the same order.
  Map<String, List<Dish>> get menuSections {
    final sections = <String, List<Dish>>{};
    for (final dish in dishes) {
      final category = dish.category.trim().isEmpty ? 'Other' : dish.category;
      sections.putIfAbsent(category, () => []).add(dish);
    }
    return sections;
  }

  @override
  List<Object?> get props => [status, restaurant, dishes, errorMessage];
}