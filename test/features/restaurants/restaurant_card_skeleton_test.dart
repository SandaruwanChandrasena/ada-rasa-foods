import 'package:ada_rasa_foods/features/restaurants/presentation/restaurant_card_skeleton.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showSkeleton(
  WidgetTester tester, {
  int count = 3,
  bool animationsOff = false,
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
          child: Scaffold(body: RestaurantSkeletonList(count: count)),
        ),
      ),
    ),
  );
}

double? shineOfFirstCard(WidgetTester tester) {
  return tester
      .widget<RestaurantCardSkeleton>(
        find.byType(RestaurantCardSkeleton).first,
      )
      .shine;
}

void main() {
  testWidgets('shows 3 grey cards by default', (tester) async {
    await showSkeleton(tester);

    expect(find.byType(RestaurantCardSkeleton), findsNWidgets(3));
  });

  testWidgets('can show a different number of cards', (tester) async {
    await showSkeleton(tester, count: 2);

    expect(find.byType(RestaurantCardSkeleton), findsNWidgets(2));
  });

  testWidgets('the shine moves across the cards', (tester) async {
    await showSkeleton(tester);

    expect(find.byType(ShaderMask), findsNWidgets(3));
    final before = shineOfFirstCard(tester);
    expect(before, isNotNull);

    await tester.pump(const Duration(milliseconds: 400));
    final after = shineOfFirstCard(tester);

    expect(after, isNotNull);
    expect(after, isNot(before));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('the shine keeps going round', (tester) async {
    await showSkeleton(tester);

    // Longer than one round (1.3 s). It must still move.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 1500));

    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('with animations off: plain grey, nothing moves',
      (tester) async {
    await showSkeleton(tester, animationsOff: true);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(RestaurantCardSkeleton), findsNWidgets(3));
    expect(shineOfFirstCard(tester), isNull);
    expect(find.byType(ShaderMask), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });
}