import 'package:ada_rasa_foods/core/router/tab_scroll.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// A tab page with a long list, like Home, plus a sideways list of chips.
Widget tabPage() {
  return Scaffold(
    body: Column(
      children: [
        // Always on screen, so tests can read the list position from here.
        const Text('Tab title'),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < 20; i++)
                SizedBox(width: 90, child: Text('Chip $i')),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (var i = 0; i < 60; i++)
                SizedBox(height: 80, child: Text('Row $i')),
            ],
          ),
        ),
      ],
    ),
  );
}

void main() {
  late TabReselectSignal signal;

  setUp(() => signal = TabReselectSignal());
  tearDown(() => signal.dispose());

  Future<void> show(WidgetTester tester, {bool reduce = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
            child: TabReselectScope(
              signal: signal,
              child: TabScroll(tab: 0, child: tabPage()),
            ),
          ),
        ),
      ),
    );
  }

  // The long list's scroll position. The title is always on screen.
  ScrollPosition listPosition(WidgetTester tester) {
    return PrimaryScrollController.of(tester.element(find.text('Tab title')))
        .position;
  }

  Future<void> scrollDown(WidgetTester tester) async {
    listPosition(tester).jumpTo(2000);
    await tester.pump();
  }

  group('TabScroll', () {
    testWidgets('only the long list uses the tab controller', (
      tester,
    ) async {
      await show(tester);

      final controller = PrimaryScrollController.of(
        tester.element(find.text('Tab title')),
      );
      expect(controller.positions, hasLength(1));
    });

    testWidgets('tapping the tab again scrolls back to the top', (
      tester,
    ) async {
      await show(tester);
      await scrollDown(tester);

      signal.reselect(0);
      await tester.pumpAndSettle();

      expect(listPosition(tester).pixels, 0);
      expect(find.text('Row 0'), findsOneWidget);
    });

    testWidgets('the scroll is smooth, not a jump', (tester) async {
      await show(tester);
      await scrollDown(tester);

      signal.reselect(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final halfway = listPosition(tester).pixels;
      expect(halfway, greaterThan(0));
      expect(halfway, lessThan(2000));

      await tester.pump(TabScroll.duration);
      expect(listPosition(tester).pixels, 0);
    });

    testWidgets('with Reduce animations it jumps to the top at once', (
      tester,
    ) async {
      await show(tester, reduce: true);
      await scrollDown(tester);

      signal.reselect(0);
      await tester.pump();

      expect(listPosition(tester).pixels, 0);
    });

    testWidgets('another tab tapped again does not move this list', (
      tester,
    ) async {
      await show(tester);
      await scrollDown(tester);

      signal.reselect(2);
      await tester.pumpAndSettle();

      expect(listPosition(tester).pixels, 2000);
    });

    testWidgets('at the top already, nothing moves', (tester) async {
      await show(tester);

      signal.reselect(0);
      await tester.pump();

      expect(listPosition(tester).pixels, 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the sideways chips are not moved', (tester) async {
      await show(tester);
      final chips = tester.state<ScrollableState>(
        find.ancestor(
          of: find.text('Chip 0'),
          matching: find.byType(Scrollable),
        ),
      );
      chips.position.jumpTo(300);
      await scrollDown(tester);

      signal.reselect(0);
      await tester.pumpAndSettle();

      expect(chips.position.pixels, 300);
      expect(listPosition(tester).pixels, 0);
    });

    testWidgets('works with no shell above it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: TabScroll(tab: 0, child: tabPage())),
      );

      expect(find.text('Row 0'), findsOneWidget);
    });

    testWidgets('a removed tab page does not crash on a late signal', (
      tester,
    ) async {
      await show(tester);
      await tester.pumpWidget(const MaterialApp(home: Text('Gone')));

      signal.reselect(0);
      await tester.pump();

      expect(find.text('Gone'), findsOneWidget);
    });
  });
}