import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/fade_slide_in.dart';
import '../domain/restaurant.dart';
import 'restaurant_card.dart';
import 'restaurant_card_skeleton.dart';
import 'restaurant_list_state.dart';

// The cuisine chips and the restaurant list on the customer home.
// The opening (chips fade in, cards fade up one by one) plays only once,
// when the restaurants first arrive.
class HomeRestaurantList extends StatefulWidget {
  const HomeRestaurantList({
    super.key,
    required this.state,
    required this.onCuisineSelected,
    required this.onRetry,
    required this.onOpen,
  });

  final RestaurantListState state;
  final ValueChanged<String?> onCuisineSelected;
  final VoidCallback onRetry;
  final ValueChanged<Restaurant> onOpen;

  // Only the first cards animate. The rest show at once.
  static const animatedCards = 6;
  static const firstCardDelay = Duration(milliseconds: 150);
  static const cardGap = Duration(milliseconds: 80);
  static const cardDuration = Duration(milliseconds: 450);
  static const chipsDuration = Duration(milliseconds: 400);
  static const switchDuration = Duration(milliseconds: 200);

  @override
  State<HomeRestaurantList> createState() => _HomeRestaurantListState();
}

class _HomeRestaurantListState extends State<HomeRestaurantList> {
  // True after the first frame that showed the loaded list.
  bool _openingPlayed = false;
  bool _endScheduled = false;

  void _endOpeningAfterThisFrame() {
    if (_endScheduled) return;
    _endScheduled = true;
    // After this frame, new cards (scroll, search, chips) show at once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openingPlayed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final loaded = state.status == RestaurantListStatus.loaded;
    if (loaded) _endOpeningAfterThisFrame();

    final reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Column(
      children: [
        if (loaded && state.cuisines.isNotEmpty)
          FadeSlideIn(
            offset: Offset.zero,
            duration: _openingPlayed
                ? Duration.zero
                : HomeRestaurantList.chipsDuration,
            child: _CuisineChips(
              cuisines: state.cuisines,
              selected: state.selectedCuisine,
              onSelected: widget.onCuisineSelected,
            ),
          ),
        Expanded(
          // Soft cross-fade from the skeleton to the cards.
          child: AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : HomeRestaurantList.switchDuration,
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [...previous, ?current],
            ),
            child: KeyedSubtree(
              key: ValueKey(state.status),
              child: _buildBody(state),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(RestaurantListState state) {
    switch (state.status) {
      case RestaurantListStatus.loading:
        return const RestaurantSkeletonList();

      case RestaurantListStatus.failure:
        return _MessageView(
          icon: Icons.wifi_off_rounded,
          message: state.errorMessage ?? 'Something went wrong.',
          buttonText: 'Retry',
          onPressed: widget.onRetry,
        );

      case RestaurantListStatus.loaded:
        final restaurants = state.visibleRestaurants;
        if (restaurants.isEmpty) {
          final noData = state.restaurants.isEmpty;
          return _MessageView(
            icon: Icons.search_off_rounded,
            message: noData
                ? 'No restaurants yet.'
                : 'No restaurants match your search.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: restaurants.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) =>
              _card(restaurants[index], index),
        );
    }
  }

  Widget _card(Restaurant restaurant, int index) {
    final card = RestaurantCard(
      restaurant: restaurant,
      onTap: () => widget.onOpen(restaurant),
    );
    if (index >= HomeRestaurantList.animatedCards) return card;

    // Same wrapper after the opening, so a card is not built from new.
    final play = !_openingPlayed;
    return FadeSlideIn(
      delay: play
          ? HomeRestaurantList.firstCardDelay +
              HomeRestaurantList.cardGap * index
          : Duration.zero,
      duration: play ? HomeRestaurantList.cardDuration : Duration.zero,
      child: card,
    );
  }
}

class _CuisineChips extends StatelessWidget {
  const _CuisineChips({
    required this.cuisines,
    required this.selected,
    required this.onSelected,
  });

  final List<String> cuisines;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    // Null stands for the "All" chip.
    final options = <String?>[null, ...cuisines];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          return Center(
            child: ChoiceChip(
              label: Text(option ?? 'All'),
              selected: option == selected,
              showCheckmark: false,
              onSelected: (_) => onSelected(option),
            ),
          );
        },
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.message,
    this.buttonText,
    this.onPressed,
  });

  final IconData icon;
  final String message;
  final String? buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (buttonText != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onPressed, child: Text(buttonText!)),
            ],
          ],
        ),
      ),
    );
  }
}