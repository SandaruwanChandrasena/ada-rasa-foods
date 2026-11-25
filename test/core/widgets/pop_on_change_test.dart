import 'package:ada_rasa_foods/core/widgets/pop_on_change.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    int value, {
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
            ),
            child: Scaffold(
              body: Center(
                child: PopOnChange(value: value, child: Text('$value')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double scaleNow(WidgetTester tester) => tester
      .widget<ScaleTransition>(
        find
            .ancestor(
              of: find.byType(Text),
              matching: find.byType(ScaleTransition),
            )
            .first,
      )
      .scale
      .value;

  testWidgets('shows the child at normal size', (tester) async {
    await show(tester, 1);

    expect(find.text('1'), findsOneWidget);
    expect(scaleNow(tester), 1.0);
  });

  testWidgets('a new value makes it grow, then settle', (tester) async {
    await show(tester, 1);

    await show(tester, 2);
    await tester.pump(const Duration(milliseconds: 100));
    expect(scaleNow(tester), greaterThan(1.1));

    await tester.pump(PopOnChange.duration);
    expect(scaleNow(tester), 1.0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the same value again does not pop', (tester) async {
    await show(tester, 1);

    await show(tester, 1);
    await tester.pump(const Duration(milliseconds: 100));

    expect(scaleNow(tester), 1.0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('with Reduce animations, it never pops', (tester) async {
    await show(tester, 1, reduceMotion: true);

    await show(tester, 2, reduceMotion: true);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('2'), findsOneWidget);
    expect(scaleNow(tester), 1.0);
    expect(tester.hasRunningAnimations, isFalse);
  });
}