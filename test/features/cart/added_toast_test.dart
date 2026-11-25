import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/features/cart/presentation/added_toast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late BuildContext pageContext;
  late int pageTaps;

  setUp(() => pageTaps = 0);

  Future<void> show(WidgetTester tester, {bool reduce = false}) async {
    // 360 x 800 points.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              pageContext = context;
              // A big button under the pop-up, to check taps go through.
              return SizedBox.expand(
                child: TextButton(
                  onPressed: () => pageTaps++,
                  child: const Text('Page'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Moves time in small steps, so animations and timers all run.
  Future<void> wait(WidgetTester tester, Duration time) async {
    final steps = time.inMilliseconds ~/ 50;
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  // Lets the pop-up go away, so the next test starts clean.
  Future<void> finish(WidgetTester tester) async {
    await wait(tester, const Duration(seconds: 3));
    expect(find.text('Added to cart'), findsNothing);
  }

  double opacity(WidgetTester tester) {
    final fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Added to cart'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    return fade.opacity.value;
  }

  group('showAddedToast', () {
    testWidgets('shows "Added to cart", the dish name and a green tick', (
      tester,
    ) async {
      await show(tester);

      showAddedToast(pageContext, dishName: 'Chicken Kottu');
      await wait(tester, const Duration(milliseconds: 300));

      expect(find.text('Added to cart'), findsOneWidget);
      expect(find.text('Chicken Kottu'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      final tick = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.check_rounded),
              matching: find.byType(Container),
            )
            .first,
      );
      final circle = tick.decoration! as BoxDecoration;
      expect(circle.color, AppTheme.successGreen);

      await finish(tester);
    });

    testWidgets('it fades in smoothly', (tester) async {
      await show(tester);

      showAddedToast(pageContext, dishName: 'Chicken Kottu');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(opacity(tester), greaterThan(0));
      expect(opacity(tester), lessThan(1));

      await finish(tester);
    });

    testWidgets('it hides by itself after about 1.5 seconds', (tester) async {
      await show(tester);

      showAddedToast(pageContext, dishName: 'Chicken Kottu');
      await wait(tester, const Duration(milliseconds: 1200));
      expect(find.text('Added to cart'), findsOneWidget);

      await wait(tester, const Duration(milliseconds: 800));
      expect(find.text('Added to cart'), findsNothing);
    });

    testWidgets('a second dish changes the name, with one box only', (
      tester,
    ) async {
      await show(tester);

      showAddedToast(pageContext, dishName: 'Chicken Kottu');
      await wait(tester, const Duration(milliseconds: 300));
      showAddedToast(pageContext, dishName: 'Egg Kottu');
      await wait(tester, const Duration(milliseconds: 100));

      expect(find.text('Added to cart'), findsOneWidget);
      expect(find.text('Egg Kottu'), findsOneWidget);
      expect(find.text('Chicken Kottu'), findsNothing);

      await finish(tester);
    });

    testWidgets('a second dish starts the time again', (tester) async {
      await show(tester);

      showAddedToast(pageContext, dishName: 'Chicken Kottu');
      await wait(tester, const Duration(milliseconds: 1000));
      showAddedToast(pageContext, dishName: 'Egg Kottu');
      // 2 seconds after the first, but only 1 after the second.
      await wait(tester, const Duration(milliseconds: 1000));

      expect(find.text('Egg Kottu'), findsOneWidget);

      await finish(tester);
    });

    testWidgets('it sits above the cart bar by default', (tester) async {
      await show(tester);

      showAddedToast(pageContext, dishName: 'Chicken Kottu');
      await wait(tester, const Duration(milliseconds: 300));

      final box = tester.getRect(
        find
            .ancestor(
              of: find.text('Added to cart'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(box.bottom, 800 - AddedToast.aboveCartBar);

      await finish(tester);
    });

    testWidgets('it uses the height it is given', (tester) async {
      await show(tester);

      showAddedToast(
        pageContext,
        dishName: 'Chicken Kottu',
        lift: AddedToast.aboveAddRow,
      );
      await wait(tester, const Duration(milliseconds: 300));

      final box = tester.getRect(
        find
            .ancestor(
              of: find.text('Added to cart'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(box.bottom, 800 - AddedToast.aboveAddRow);

      await finish(tester);
    });

    testWidgets('taps go through it to the page', (tester) async {
      await show(tester);

      showAddedToast(pageContext, dishName: 'Chicken Kottu');
      await wait(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Added to cart'), warnIfMissed: false);
      await tester.pump();

      expect(pageTaps, 1);

      await finish(tester);
    });

    testWidgets('with Reduce animations it shows at once', (tester) async {
      await show(tester, reduce: true);

      showAddedToast(pageContext, dishName: 'Chicken Kottu');
      await tester.pump();
      await tester.pump();

      expect(opacity(tester), 1);

      await finish(tester);
    });

    testWidgets('a very long dish name fits on one line', (tester) async {
      await show(tester);

      showAddedToast(
        pageContext,
        dishName: 'Extra Large Chicken and Cheese Kottu with Egg and '
            'Spicy Curry Sauce',
      );
      await wait(tester, const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);

      await finish(tester);
    });
  });
}