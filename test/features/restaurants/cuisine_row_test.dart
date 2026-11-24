import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/cuisine_row.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('CuisineRow.iconFor', () {
    test('Sri Lankan food gets a rice bowl', () {
      expect(CuisineRow.iconFor('Sri Lankan'), Icons.rice_bowl_rounded);
      expect(CuisineRow.iconFor('Kottu'), Icons.rice_bowl_rounded);
    });

    test('Chinese food gets noodles', () {
      expect(CuisineRow.iconFor('Chinese'), Icons.ramen_dining_rounded);
    });

    test('pizza and Italian get a pizza slice', () {
      expect(CuisineRow.iconFor('Pizza'), Icons.local_pizza_rounded);
      expect(CuisineRow.iconFor('Italian'), Icons.local_pizza_rounded);
    });

    test('other known cuisines get their own icons', () {
      expect(CuisineRow.iconFor('Burgers'), Icons.lunch_dining_rounded);
      expect(CuisineRow.iconFor('Indian'), Icons.soup_kitchen_rounded);
      expect(CuisineRow.iconFor('Seafood'), Icons.set_meal_rounded);
      expect(CuisineRow.iconFor('Bakery'), Icons.cake_rounded);
      expect(CuisineRow.iconFor('Cafe'), Icons.local_cafe_rounded);
      expect(CuisineRow.iconFor('Fresh Juice'), Icons.local_drink_rounded);
    });

    test('capital letters do not matter', () {
      expect(CuisineRow.iconFor('SRI LANKAN'), Icons.rice_bowl_rounded);
    });

    test('an unknown cuisine gets a fork and knife', () {
      expect(CuisineRow.iconFor('Thai'), Icons.restaurant_menu_rounded);
      expect(CuisineRow.iconFor(''), Icons.restaurant_menu_rounded);
    });
  });

  group('CuisineRow', () {
    late List<String?> picked;

    setUp(() => picked = []);

    Future<void> show(
      WidgetTester tester, {
      List<String> cuisines = const ['Sri Lankan', 'Chinese'],
      String? selected,
      bool reduce = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
              child: Scaffold(
                body: CuisineRow(
                  cuisines: cuisines,
                  selected: selected,
                  onSelected: picked.add,
                ),
              ),
            ),
          ),
        ),
      );
    }

    List<String> labels(WidgetTester tester) => [
          for (final button in tester.widgetList<CuisineButton>(
            find.byType(CuisineButton),
          ))
            button.label,
        ];

    BoxDecoration circleOf(WidgetTester tester, String label) {
      final circle = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.widgetWithText(CuisineButton, label),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return circle.decoration! as BoxDecoration;
    }

    testWidgets('shows All first, then each cuisine', (tester) async {
      await show(tester);

      expect(labels(tester), ['All', 'Sri Lankan', 'Chinese']);
    });

    testWidgets('tapping a cuisine sends its name', (tester) async {
      await show(tester);

      await tester.tap(find.text('Chinese'));
      await tester.pump();

      expect(picked, ['Chinese']);
    });

    testWidgets('tapping All sends null', (tester) async {
      await show(tester, selected: 'Chinese');

      await tester.tap(find.text('All'));
      await tester.pump();

      expect(picked, [null]);
    });

    testWidgets('a button that is not selected is grey with an orange icon',
        (tester) async {
      await show(tester);

      expect(circleOf(tester, 'Chinese').color, CuisineButton.idleBackground);
      expect(circleOf(tester, 'Chinese').shape, BoxShape.circle);
      final icon = tester.widget<Icon>(find.byIcon(Icons.ramen_dining_rounded));
      expect(icon.color, AppTheme.brandOrange);
    });

    testWidgets('the selected button is orange with a white icon', (
      tester,
    ) async {
      await show(tester, selected: 'Sri Lankan');

      expect(circleOf(tester, 'Sri Lankan').color, AppTheme.brandOrange);
      final icon = tester.widget<Icon>(find.byIcon(Icons.rice_bowl_rounded));
      expect(icon.color, Colors.white);
    });

    testWidgets('a long cuisine name fits with no overflow', (tester) async {
      await show(
        tester,
        cuisines: const ['Traditional Sri Lankan Village Food'],
      );

      expect(tester.takeException(), isNull);
      final size = tester.getSize(
        find.widgetWithText(
          CuisineButton,
          'Traditional Sri Lankan Village Food',
        ),
      );
      expect(size.width, lessThanOrEqualTo(72));
    });

    testWidgets('the colour change is smooth', (tester) async {
      await show(tester);

      final circle = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.widgetWithText(CuisineButton, 'All'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(circle.duration, CuisineButton.duration);
    });

    testWidgets('with Reduce animations the colour changes at once', (
      tester,
    ) async {
      await show(tester, reduce: true);

      final circle = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.widgetWithText(CuisineButton, 'All'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(circle.duration, Duration.zero);
    });
  });
}