import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/fade_slide_in.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/home/cuisine_row.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/home/home_restaurant_list.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/home/restaurant_card.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/home/restaurant_card_skeleton.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/home/restaurant_list_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Even numbers are Sri Lankan, odd numbers are Chinese.
Restaurant place(int i) {
  return Restaurant(
    id: 'r$i',
    name: 'Place $i',
    cuisine: i.isEven ? 'Sri Lankan' : 'Chinese',
    ownerId: 'o$i',
    address: 'Colombo $i',
    latitude: 6.9,
    longitude: 79.8,
  );
}

RestaurantListState loadedWith(int count) {
  return RestaurantListState(
    status: RestaurantListStatus.loaded,
    restaurants: [for (var i = 0; i < count; i++) place(i)],
  );
}

// How visible a card is, from 0 (hidden) to 1 (shown).
double opacityOf(WidgetTester tester, String name) {
  final fade = find
      .descendant(
        of: find.ancestor(
          of: find.text(name),
          matching: find.byType(FadeSlideIn),
        ),
        matching: find.byType(FadeTransition),
      )
      .first;
  return tester.widget<FadeTransition>(fade).opacity.value;
}

void main() {
  late ValueNotifier<RestaurantListState> list;
  late List<String> opened;
  late int retries;

  setUp(() {
    list = ValueNotifier(const RestaurantListState());
    opened = [];
    retries = 0;
  });

  Future<void> showList(
    WidgetTester tester, {
    bool animationsOff = false,
    Widget? header,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: animationsOff),
            child: Scaffold(
              body: ValueListenableBuilder<RestaurantListState>(
                valueListenable: list,
                builder: (context, state, _) => HomeRestaurantList(
                  state: state,
                  onCuisineSelected: (cuisine) => list.value =
                      list.value.copyWith(selectedCuisine: () => cuisine),
                  onRetry: () => retries++,
                  onOpen: (restaurant) => opened.add(restaurant.id),
                  header: header,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showLoaded(WidgetTester tester, int count) async {
    await showList(tester);
    list.value = loadedWith(count);
    await tester.pumpAndSettle();
  }

  testWidgets('shows skeleton cards while loading', (tester) async {
    await showList(tester);

    expect(find.byType(RestaurantCardSkeleton), findsNWidgets(3));
    expect(find.byType(RestaurantCard), findsNothing);
    expect(find.byType(CuisineButton), findsNothing);
  });

  testWidgets('cards fade up one by one after loading', (tester) async {
    await showList(tester);
    list.value = loadedWith(8);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Card 1 has started. Card 3 waits for its turn (starts at 310 ms).
    // Card 4 is below the screen edge, so the finder can't see it.
    expect(opacityOf(tester, 'Place 0'), greaterThan(0));
    expect(opacityOf(tester, 'Place 2'), 0);

    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      expect(opacityOf(tester, 'Place $i'), 1);
    }
    expect(find.byType(RestaurantCardSkeleton), findsNothing);
  });

  testWidgets('cuisine buttons fade in when the restaurants arrive',
      (tester) async {
    await showList(tester);
    list.value = loadedWith(4);
    await tester.pump();

    final chips = find.ancestor(
      of: find.byType(CuisineButton).first,
      matching: find.byType(FadeSlideIn),
    );
    expect(chips, findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.widgetWithText(CuisineButton, 'All'), findsOneWidget);
    expect(find.widgetWithText(CuisineButton, 'Chinese'), findsOneWidget);
    expect(find.widgetWithText(CuisineButton, 'Sri Lankan'), findsOneWidget);
  });

  testWidgets('card 7 and later show at once, with no animation',
      (tester) async {
    await showLoaded(tester, 8);

    await tester.dragUntilVisible(
      find.text('Place 6'),
      find.byType(Scaffold),
      const Offset(0, -300),
    );

    final wrapper = find.ancestor(
      of: find.text('Place 6'),
      matching: find.byType(FadeSlideIn),
    );
    expect(wrapper, findsNothing);
  });

  testWidgets('scrolling down and back up does not play it again',
      (tester) async {
    await showLoaded(tester, 8);

    await tester.dragUntilVisible(
      find.text('Place 6'),
      find.byType(Scaffold),
      const Offset(0, -300),
    );
    await tester.drag(
      find.byType(Scaffold),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    // Card 1 is far away now, so the list removed it.
    expect(find.text('Place 0'), findsNothing);

    await tester.dragUntilVisible(
      find.text('Place 0'),
      find.byType(Scaffold),
      const Offset(0, 300),
    );

    // Built again, but shown at once.
    expect(opacityOf(tester, 'Place 0'), 1);
  });

  testWidgets('a search does not play it again', (tester) async {
    await showLoaded(tester, 8);

    list.value = list.value.copyWith(searchText: 'zzz');
    await tester.pump();
    expect(find.text('No restaurants match your search.'), findsOneWidget);

    list.value = list.value.copyWith(searchText: '');
    await tester.pump();

    // The list is new, but the cards show at once.
    expect(opacityOf(tester, 'Place 0'), 1);
    expect(opacityOf(tester, 'Place 1'), 1);
  });

  testWidgets('a cuisine tap does not play it again', (tester) async {
    await showLoaded(tester, 8);

    await tester.tap(find.widgetWithText(CuisineButton, 'Chinese'));
    await tester.pump();

    expect(find.text('Place 0'), findsNothing);
    expect(opacityOf(tester, 'Place 1'), 1);
    expect(opacityOf(tester, 'Place 3'), 1);
  });

  testWidgets('with animations off, cards show at once', (tester) async {
    await showList(tester, animationsOff: true);
    list.value = loadedWith(8);
    await tester.pump();
    await tester.pump();

    expect(opacityOf(tester, 'Place 0'), 1);
    expect(opacityOf(tester, 'Place 2'), 1);
    expect(find.byType(RestaurantCardSkeleton), findsNothing);
  });

  testWidgets('tapping a card opens that restaurant', (tester) async {
    await showLoaded(tester, 4);

    // The round cuisine row is taller, so card 3 starts below the screen.
    await tester.ensureVisible(find.text('Place 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Place 2'));
    await tester.pump();

    expect(opened, ['r2']);
  });

  testWidgets('an error shows Retry, and Retry calls the cubit',
      (tester) async {
    await showList(tester);
    list.value = const RestaurantListState(
      status: RestaurantListStatus.failure,
      errorMessage: 'No internet connection.',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No internet connection.'), findsOneWidget);
    expect(find.byType(RestaurantCardSkeleton), findsNothing);

    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('after a retry, the skeleton shows again', (tester) async {
    await showList(tester);
    list.value = const RestaurantListState(
      status: RestaurantListStatus.failure,
      errorMessage: 'No internet connection.',
    );
    await tester.pumpAndSettle();

    list.value = const RestaurantListState();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(RestaurantCardSkeleton), findsNWidgets(3));
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('no restaurants shows a message and no cuisine buttons',
      (tester) async {
    await showLoaded(tester, 0);

    expect(find.text('No restaurants yet.'), findsOneWidget);
    expect(find.byType(CuisineButton), findsNothing);
  });

  group('header', () {
    const banner = SizedBox(height: 80, child: Text('Welcome'));

    Future<void> showWithHeader(WidgetTester tester, Widget header) async {
      await showList(tester, header: header);
      list.value = loadedWith(8);
      await tester.pumpAndSettle();
    }

    testWidgets('shows above the first card', (tester) async {
      await showWithHeader(tester, banner);

      final headerTop = tester.getTopLeft(find.text('Welcome')).dy;
      final cardTop = tester.getTopLeft(find.text('Place 0')).dy;
      expect(headerTop, lessThan(cardTop));
    });

    testWidgets('is not shown while loading or after an error', (
      tester,
    ) async {
      await showList(tester, header: banner);
      expect(find.text('Welcome'), findsNothing);

      list.value = const RestaurantListState(
        status: RestaurantListStatus.failure,
        errorMessage: 'No internet connection.',
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsNothing);
    });

    testWidgets('scrolls away with the list', (tester) async {
      await showWithHeader(tester, banner);

      await tester.drag(find.text('Place 1'), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(find.text('Welcome'), findsNothing);
    });

    testWidgets('a hidden header leaves no gap above the first card', (
      tester,
    ) async {
      await showLoaded(tester, 4);
      final plainTop = tester.getTopLeft(find.text('Place 0')).dy;

      await showWithHeader(tester, const SizedBox.shrink());
      final hiddenTop = tester.getTopLeft(find.text('Place 0')).dy;

      expect(hiddenTop, plainTop);
    });

    testWidgets('the first card still fades in first', (tester) async {
      await showList(tester, header: banner);
      list.value = loadedWith(8);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(opacityOf(tester, 'Place 0'), greaterThan(0));
      expect(opacityOf(tester, 'Place 2'), 0);
    });

    testWidgets('tapping a card under the header opens the right one', (
      tester,
    ) async {
      await showWithHeader(tester, banner);

      await tester.tap(find.text('Place 0'));
      await tester.pump();

      expect(opened, ['r0']);
    });
  });

  group('cuisine buttons', () {
    CuisineButton button(WidgetTester tester, String label) {
      return tester.widget<CuisineButton>(
        find.widgetWithText(CuisineButton, label),
      );
    }

    testWidgets('All is selected at first', (tester) async {
      await showLoaded(tester, 4);

      expect(button(tester, 'All').selected, isTrue);
      expect(button(tester, 'Chinese').selected, isFalse);
    });

    testWidgets('each cuisine has its own icon', (tester) async {
      await showLoaded(tester, 4);

      expect(button(tester, 'All').icon, Icons.restaurant_rounded);
      expect(button(tester, 'Sri Lankan').icon, Icons.rice_bowl_rounded);
      expect(button(tester, 'Chinese').icon, Icons.ramen_dining_rounded);
    });

    testWidgets('tapping a cuisine selects it and filters the list', (
      tester,
    ) async {
      await showLoaded(tester, 4);

      await tester.tap(find.widgetWithText(CuisineButton, 'Sri Lankan'));
      await tester.pumpAndSettle();

      expect(button(tester, 'Sri Lankan').selected, isTrue);
      expect(button(tester, 'All').selected, isFalse);
      expect(find.text('Place 0'), findsOneWidget);
      expect(find.text('Place 1'), findsNothing);
    });

    testWidgets('tapping All shows every restaurant again', (tester) async {
      await showLoaded(tester, 4);
      await tester.tap(find.widgetWithText(CuisineButton, 'Chinese'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CuisineButton, 'All'));
      await tester.pumpAndSettle();

      expect(button(tester, 'All').selected, isTrue);
      expect(find.text('Place 0'), findsOneWidget);
      expect(find.text('Place 1'), findsOneWidget);
    });

    testWidgets('the selected circle is orange with a white icon', (
      tester,
    ) async {
      await showLoaded(tester, 4);
      await tester.tap(find.widgetWithText(CuisineButton, 'Chinese'));
      await tester.pumpAndSettle();

      final circle = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.widgetWithText(CuisineButton, 'Chinese'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final box = circle.decoration! as BoxDecoration;
      expect(box.color, AppTheme.brandOrange);

      final icon = tester.widget<Icon>(find.byIcon(Icons.ramen_dining_rounded));
      expect(icon.color, Colors.white);
    });

    testWidgets('the cuisine row stays put when the list scrolls', (
      tester,
    ) async {
      await showLoaded(tester, 8);
      final before = tester.getTopLeft(find.text('All')).dy;

      await tester.drag(find.text('Place 1'), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('All')).dy, before);
    });
  });
}