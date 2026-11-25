import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/food_image.dart';
import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:ada_rasa_foods/features/menu/presentation/dish_row.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const kottu = Dish(
  id: 'd1',
  restaurantId: 'r1',
  name: 'Chicken Kottu',
  price: 1200,
  category: 'Kottu',
  description: 'Chopped roti with chicken, egg, leeks and our own spicy '
      'curry sauce, made fresh on a hot iron plate.',
);

const soldOut = Dish(
  id: 'd2',
  restaurantId: 'r1',
  name: 'Cheese Kottu',
  price: 1500,
  category: 'Kottu',
  available: false,
);

void main() {
  late int taps;

  setUp(() => taps = 0);

  Future<void> show(
    WidgetTester tester,
    Dish dish, {
    bool tappable = true,
    Widget? trailing,
  }) async {
    // A small phone, 360 points wide.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DishRow(
                dish: dish,
                trailing: trailing,
                onTap: tappable ? () => taps++ : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Finder fadeLayer() => find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == DishRow.notAvailableFade,
      );

  Color? colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  group('DishRow', () {
    testWidgets('shows the name, one line of description and the price', (
      tester,
    ) async {
      await show(tester, kottu);

      expect(find.text('Chicken Kottu'), findsOneWidget);
      expect(find.text('Rs. 1,200'), findsOneWidget);

      final description = tester.widget<Text>(find.text(kottu.description));
      expect(description.maxLines, 1);
      expect(description.overflow, TextOverflow.ellipsis);
    });

    testWidgets('the price is orange and the name is dark', (tester) async {
      await show(tester, kottu);

      expect(colorOf(tester, 'Rs. 1,200'), AppTheme.brandOrange);
      expect(colorOf(tester, 'Chicken Kottu'), AppTheme.textDark);
    });

    testWidgets('the photo is 88 square', (tester) async {
      await show(tester, kottu);

      expect(tester.getSize(find.byType(FoodImage)), const Size(88, 88));
    });

    testWidgets('a dish with no description shows no empty line', (
      tester,
    ) async {
      const plain = Dish(
        id: 'd3',
        restaurantId: 'r1',
        name: 'Plain Roti',
        price: 100,
        category: 'Roti',
      );
      await show(tester, plain);

      expect(find.text('Plain Roti'), findsOneWidget);

      expect(find.text(''), findsNothing);
    });

    testWidgets('not available: soft red label, faded photo, grey text', (
      tester,
    ) async {
      await show(tester, soldOut);

      expect(find.text('Not available'), findsOneWidget);
      expect(colorOf(tester, 'Not available'), AppTheme.dangerRed);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(fadeLayer(), findsOneWidget);
      expect(colorOf(tester, 'Cheese Kottu'), AppTheme.textMuted);
      expect(colorOf(tester, 'Rs. 1,500'), AppTheme.textMuted);
    });

    testWidgets('not available does not use Opacity', (tester) async {
      await show(tester, soldOut);

      expect(
        find.descendant(
          of: find.byType(DishRow),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets('an available dish has no label and no fade', (tester) async {
      await show(tester, kottu);

      expect(find.text('Not available'), findsNothing);
      expect(fadeLayer(), findsNothing);
    });

    testWidgets('a tappable row is a card with a light border', (
      tester,
    ) async {
      await show(tester, kottu);

      final card = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(DishRow),
              matching: find.byType(Material),
            )
            .first,
      );
      final shape = card.shape! as RoundedRectangleBorder;
      expect(shape.side.color, AppTheme.border);
      expect(shape.borderRadius, BorderRadius.circular(16));
    });

    testWidgets('tapping the row opens the dish', (tester) async {
      await show(tester, kottu);

      await tester.tap(find.text('Chicken Kottu'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('a row with no tap (owner Menu tab) is not a card', (
      tester,
    ) async {
      await show(tester, kottu, tappable: false);

      expect(
        find.descendant(
          of: find.byType(DishRow),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
      expect(find.byType(Hero), findsNothing);
    });

    testWidgets('the trailing button shows next to the price', (
      tester,
    ) async {
      await show(tester, kottu, trailing: const Text('Add'));

      final price = tester.getCenter(find.text('Rs. 1,200'));
      final add = tester.getCenter(find.text('Add'));
      expect(add.dx, greaterThan(price.dx));
      expect((add.dy - price.dy).abs(), lessThan(20));
    });

    testWidgets('a very long name fits with no overflow', (tester) async {
      const longName = Dish(
        id: 'd4',
        restaurantId: 'r1',
        name: 'Extra Large Chicken and Cheese Kottu with Egg and '
            'Spicy Curry Sauce',
        price: 2400,
        category: 'Kottu',
        description: 'A very long description that goes on and on.',
      );
      await show(tester, longName, trailing: const Text('Add'));

      expect(tester.takeException(), isNull);
    });
  });
}