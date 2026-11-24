import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/round_icon_button.dart';
import 'package:ada_rasa_foods/features/cart/presentation/fly_to_cart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Stands in for the round cart button at the top right.
class FakeCart implements CartFlyTarget {
  int bounces = 0;

  @override
  Offset? get centerOnScreen => const Offset(340, 40);

  @override
  void bounce() => bounces++;
}

void main() {
  late FakeCart cart;

  setUp(() {
    cart = FakeCart();
    registerCartTarget(cart);
  });

  tearDown(() => unregisterCartTarget(cart));

  Future<void> show(WidgetTester tester) async {
    // Redmi size: top bar icons are 26, so round buttons are 38.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    // Flights need a short real gap between them, even across tests.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AppThemeByWidth(child: child!),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              key: Key('dish'),
              width: 60,
              height: 60,
            ),
          ),
        ),
      ),
    );
  }

  BuildContext dishContext(WidgetTester tester) =>
      tester.element(find.byKey(const Key('dish')));

  // The photo's white edge: a circle border drawn on top of it.
  Finder whiteEdge() => find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.position == DecorationPosition.foreground &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle &&
            (w.decoration as BoxDecoration).border ==
                Border.all(color: Colors.white, width: 2),
      );

  // Lets the photo land and the bin close, so the next test starts clean.
  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
  }

  group('flyToBin', () {
    testWidgets('the bin is a soft red round button', (tester) async {
      await show(tester);

      flyToBin(dishContext(tester), imageUrl: '');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final bin = tester.widget<RoundIconCircle>(find.byType(RoundIconCircle));
      expect(bin.style, RoundIconStyle.danger);
      expect(bin.icon, Icons.delete_rounded);
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      await finish(tester);
    });

    testWidgets('the bin sits left of the cart, the same size', (
      tester,
    ) async {
      await show(tester);

      flyToBin(dishContext(tester), imageUrl: '');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final bin = find.byType(RoundIconCircle);
      expect(tester.getSize(bin), const Size(38, 38));
      expect(tester.getCenter(bin), const Offset(340 - 46, 40));

      await finish(tester);
    });

    testWidgets('the flying photo has a white edge', (tester) async {
      await show(tester);

      flyToBin(dishContext(tester), imageUrl: '');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(whiteEdge(), findsOneWidget);

      await finish(tester);
    });

    testWidgets('the bin goes away after the photo drops in', (
      tester,
    ) async {
      await show(tester);

      flyToBin(dishContext(tester), imageUrl: '');
      await tester.pump();
      await finish(tester);

      expect(find.byType(RoundIconCircle), findsNothing);
      expect(whiteEdge(), findsNothing);
    });
  });

  group('flyToCart', () {
    testWidgets('the photo has a white edge and the cart bounces', (
      tester,
    ) async {
      await show(tester);

      flyToCart(dishContext(tester), imageUrl: '');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(whiteEdge(), findsOneWidget);

      await finish(tester);

      expect(cart.bounces, 1);
      expect(whiteEdge(), findsNothing);
    });
  });
}