import 'package:equatable/equatable.dart';

import '../domain/restaurant.dart';

enum RestaurantListStatus { loading, loaded, failure }

class RestaurantListState extends Equatable {
  const RestaurantListState({
    this.status = RestaurantListStatus.loading,
    this.restaurants = const [],
    this.searchText = '',
    this.selectedCuisine,
    this.errorMessage,
  });

  final RestaurantListStatus status;

  // All active restaurants from Firestore, before search and chip filter.
  final List<Restaurant> restaurants;

  final String searchText;

  // Null means the "All" chip is chosen.
  final String? selectedCuisine;

  final String? errorMessage;

  // Chip names, from the cuisines of the loaded restaurants.
  List<String> get cuisines {
    final names = restaurants
        .map((r) => r.cuisine.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  // The list the home screen shows. Closed restaurants stay in it.
  List<Restaurant> get visibleRestaurants {
    final query = searchText.trim().toLowerCase();

    return restaurants.where((r) {
      final cuisineOk =
          selectedCuisine == null || r.cuisine.trim() == selectedCuisine;
      final searchOk = query.isEmpty ||
          r.name.toLowerCase().contains(query) ||
          r.cuisine.toLowerCase().contains(query);
      return cuisineOk && searchOk;
    }).toList();
  }

  RestaurantListState copyWith({
    RestaurantListStatus? status,
    List<Restaurant>? restaurants,
    String? searchText,
    String? Function()? selectedCuisine,
    String? Function()? errorMessage,
  }) {
    return RestaurantListState(
      status: status ?? this.status,
      restaurants: restaurants ?? this.restaurants,
      searchText: searchText ?? this.searchText,
      // A function lets us set the value back to null.
      selectedCuisine:
          selectedCuisine != null ? selectedCuisine() : this.selectedCuisine,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        restaurants,
        searchText,
        selectedCuisine,
        errorMessage,
      ];
}