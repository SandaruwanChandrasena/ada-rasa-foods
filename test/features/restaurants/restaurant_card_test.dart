import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/food_image.dart';
import 'package:ada_rasa_foods/core/widgets/open_status_chip.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/restaurant_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Restaurant kottuCorner({
  bool isOpen = true,
  bool isActive = true,
  String name = 'Kottu Corner',
  String address = 'Galle Road, Colombo 03',
}) {
  return Restaurant(
    id: 'r1',
    name: name,
    cuisine: 'Sri Lankan',
    ownerId: 'o1',
    address: address,
    latitude: 6.9,
    longitude: 79.8,
    isOpen: isOpen,
    isActive: isActive,
  );
}

void main() {
  late int taps;

  setUp(() => taps = 0);

  Future<void> show(WidgetTester tester, Restaurant restaurant) async {
    // Redmi size: about 393 points wide.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RestaurantCard(restaurant: restaurant, onTap: () => taps++),
            ],
          ),
        ),
      ),
    );
  }

  Finder fadeLayer() => find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == RestaurantCard.closedFade,
      );

  group('RestaurantCard', () {
    testWidgets('shows the name, cuisine and address', (tester) async {
      await show(tester, kottuCorner());

      expect(find.text('Kottu Corner'), findsOneWidget);
      expect(find.text('Sri Lankan'), findsOneWidget);
      expect(find.text('Galle Road, Colombo 03'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
    });

    testWidgets('an open place: green Open chip and no fade', (tester) async {
      await show(tester, kottuCorner());

      final chip = tester.widget<OpenStatusChip>(find.byType(OpenStatusChip));
      expect(chip.isOpen, isTrue);
      expect(find.text('Open'), findsOneWidget);
      expect(fadeLayer(), findsNothing);
    });

    testWidgets('a closed place: red Closed chip and a faded photo', (
      tester,
    ) async {
      await show(tester, kottuCorner(isOpen: false));

      expect(find.text('Closed'), findsOneWidget);
      expect(fadeLayer(), findsOneWidget);

      final name = tester.widget<Text>(find.text('Kottu Corner'));
      expect(name.style?.color, AppTheme.textMuted);
    });

    testWidgets('a place turned off by the admin shows Closed too', (
      tester,
    ) async {
      await show(tester, kottuCorner(isActive: false));

      expect(find.text('Closed'), findsOneWidget);
      expect(fadeLayer(), findsOneWidget);
    });

    testWidgets('the chip sits on the bottom left of the photo', (
      tester,
    ) async {
      await show(tester, kottuCorner());

      final photo = tester.getRect(find.byType(FoodImage));
      final chip = tester.getRect(find.byType(OpenStatusChip));
      expect(chip.left, photo.left + 10);
      expect(chip.bottom, photo.bottom - 10);
    });

    testWidgets('tapping opens the place, even when it is closed', (
      tester,
    ) async {
      await show(tester, kottuCorner(isOpen: false));

      await tester.tap(find.text('Kottu Corner'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('a place with no photo still shows the chip', (tester) async {
      await show(tester, kottuCorner());

      expect(find.byType(FoodImage), findsOneWidget);
      expect(find.byType(OpenStatusChip), findsOneWidget);
    });

    testWidgets('a long name and address fit with no overflow', (
      tester,
    ) async {
      await show(
        tester,
        kottuCorner(
          name: 'The Very Famous Original Colombo Kottu and Rice Corner',
          address: 'No. 1234, Very Long Galle Road, Bambalapitiya, '
              'Colombo 04, Western Province',
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('the card has no outside margin, so it lines up', (
      tester,
    ) async {
      await show(tester, kottuCorner());

      expect(tester.widget<Card>(find.byType(Card)).margin, EdgeInsets.zero);
    });
  });
}