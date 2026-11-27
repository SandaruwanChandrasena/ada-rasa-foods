import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:ada_rasa_foods/features/menu/presentation/owner_dish_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Dish dish({
  String name = 'Chicken Kottu',
  bool available = true,
}) {
  return Dish(
    id: 'd1',
    restaurantId: 'r1',
    name: name,
    price: 950,
    category: 'Kottu',
    available: available,
  );
}

void main() {
  late int edits;
  late List<bool> switches;

  setUp(() {
    edits = 0;
    switches = [];
  });

  Future<void> show(
    WidgetTester tester,
    Dish dish, {
    bool busy = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: OwnerDishCard(
                dish: dish,
                busy: busy,
                onEdit: () => edits++,
                onAvailable: switches.add,
              ),
            ),
          ),
        ),
      ),
    );
    if (busy) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  testWidgets('an available dish: name, orange price, green Available',
      (tester) async {
    await show(tester, dish());

    expect(find.text('Chicken Kottu'), findsOneWidget);
    expect(textColor(tester, 'Rs. 950'), AppTheme.brandOrange);
    expect(textColor(tester, 'Available'), AppTheme.successGreen);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.byKey(const Key('not-available-fade')), findsNothing);
  });

  testWidgets('a hidden dish: red Not available, faded photo, switch off',
      (tester) async {
    await show(tester, dish(available: false));

    expect(textColor(tester, 'Not available'), AppTheme.dangerRed);
    expect(textColor(tester, 'Chicken Kottu'), AppTheme.textMuted);
    expect(textColor(tester, 'Rs. 950'), AppTheme.textMuted);
    expect(find.byKey(const Key('not-available-fade')), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('a dish with no photo shows the food icon', (tester) async {
    await show(tester, dish());

    expect(find.byIcon(Icons.fastfood_rounded), findsOneWidget);
  });

  testWidgets('the card is white with a thin border and radius 16',
      (tester) async {
    await show(tester, dish());

    final card = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(OwnerDishCard),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(card.color, Colors.white);
    expect(
      card.shape,
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
    );
  });

  testWidgets('tapping the card opens Edit', (tester) async {
    await show(tester, dish());

    await tester.tap(find.text('Chicken Kottu'));
    await tester.pumpAndSettle();

    expect(edits, 1);
  });

  testWidgets('the round soft orange pencil opens Edit', (tester) async {
    await show(tester, dish());

    final pencil = find.byKey(const ValueKey('edit-d1'));
    expect(tester.widget<Material>(pencil).color, AppTheme.softOrange);
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);

    await tester.tap(pencil);
    await tester.pumpAndSettle();

    expect(edits, 1);
  });

  testWidgets('the switch sends the new value, not an Edit',
      (tester) async {
    await show(tester, dish());

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(switches, [false]);
    expect(edits, 0);
  });

  testWidgets('while saving: a spinner, not the switch', (tester) async {
    await show(tester, dish(), busy: true);

    expect(find.byType(Switch), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a very long name does not overflow', (tester) async {
    await show(
      tester,
      dish(name: 'Special Cheese Chicken Kottu With Extra Egg And Gravy'),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Rs. 950'), findsOneWidget);
  });
}