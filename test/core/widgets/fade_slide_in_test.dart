import 'package:ada_rasa_foods/core/widgets/fade_slide_in.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// How visible the FadeSlideIn is, from 0 (hidden) to 1 (shown).
double opacityOf(WidgetTester tester) {
  final fade = tester.widget<FadeTransition>(
    find
        .descendant(
          of: find.byType(FadeSlideIn),
          matching: find.byType(FadeTransition),
        )
        .first,
  );
  return fade.opacity.value;
}

// How far the FadeSlideIn is from its end place, in pixels.
double slideOf(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find
        .descendant(
          of: find.byType(FadeSlideIn),
          matching: find.byType(Transform),
        )
        .first,
  );
  return transform.transform.getTranslation().y;
}

void main() {
  testWidgets('starts hidden and lower, then ends shown in place',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FadeSlideIn(child: Text('Hello'))),
    );

    expect(opacityOf(tester), 0);
    expect(slideOf(tester), 16);

    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
    expect(slideOf(tester), 0);
  });

  testWidgets('waits for its delay before it starts', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FadeSlideIn(
          delay: Duration(milliseconds: 300),
          child: Text('Hello'),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));
    expect(opacityOf(tester), 0);

    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
  });

  testWidgets('waits until the page has slid in', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: FadeSlideIn(child: Text('New page')),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The page is still sliding in, so it has not started yet.
    expect(opacityOf(tester), 0);

    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
  });

  testWidgets('shows at once when the phone has animations off',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const FadeSlideIn(
              delay: Duration(milliseconds: 300),
              child: Text('Hello'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(opacityOf(tester), 1);
    expect(slideOf(tester), 0);
  });

  testWidgets('a pop-in grows from its start size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FadeSlideIn(
          offset: Offset.zero,
          scaleFrom: 0.7,
          child: Text('Logo'),
        ),
      ),
    );

    double scale() {
      final transforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(FadeSlideIn),
          matching: find.byType(Transform),
        ),
      );
      // The second Transform is the size change. Its first number is the
      // width scale. (getMaxScaleOnAxis also counts depth, which stays 1.)
      return transforms.elementAt(1).transform.storage[0];
    }

    expect(scale(), closeTo(0.7, 0.001));
    await tester.pumpAndSettle();
    expect(scale(), closeTo(1, 0.001));
  });
}