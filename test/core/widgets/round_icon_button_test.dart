import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/round_icon_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Redmi: 1080 x 2400 pixels at 2.75 is about 393 points wide (normal).
void setRedmi(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

// Realme: 720 x 1600 pixels at 1.7 is about 424 points wide (large).
void setRealme(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 1.7;
  addTearDown(tester.view.reset);
}

Widget app(Widget home) {
  return MaterialApp(
    builder: (context, child) => AppThemeByWidth(child: child!),
    home: home,
  );
}

BoxDecoration circleOf(WidgetTester tester, Finder circle) {
  final box = tester.widget<Container>(
    find.descendant(of: circle, matching: find.byType(Container)).first,
  );
  return box.decoration! as BoxDecoration;
}

// A page with a button that opens a second page with a top bar.
class FirstPage extends StatelessWidget {
  const FirstPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Second page')),
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    );
  }
}

void main() {
  group('RoundIconCircle', () {
    testWidgets('soft style: orange icon on soft orange, no border', (
      tester,
    ) async {
      setRedmi(tester);
      await tester.pumpWidget(
        app(const Scaffold(body: RoundIconCircle(icon: Icons.home_rounded))),
      );

      final circle = circleOf(tester, find.byType(RoundIconCircle));
      expect(circle.color, AppTheme.softOrange);
      expect(circle.shape, BoxShape.circle);
      expect(circle.border, isNull);

      final icon = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
      expect(icon.color, AppTheme.brandOrange);
    });

    testWidgets('on photo style: dark icon on white, no border', (
      tester,
    ) async {
      setRedmi(tester);
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: RoundIconCircle(
              icon: Icons.home_rounded,
              style: RoundIconStyle.onPhoto,
            ),
          ),
        ),
      );

      final circle = circleOf(tester, find.byType(RoundIconCircle));
      expect(circle.color, Colors.white);
      expect(circle.border, isNull);

      final icon = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
      expect(icon.color, AppTheme.textDark);
    });
  });

  group('RoundIconButton', () {
    testWidgets('tapping it calls onPressed', (tester) async {
      setRedmi(tester);
      var taps = 0;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: RoundIconButton(
              icon: Icons.person_rounded,
              tooltip: 'Profile',
              onPressed: () => taps++,
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Profile'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('with no onPressed it does nothing and does not crash', (
      tester,
    ) async {
      setRedmi(tester);
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: RoundIconButton(icon: Icons.person_rounded, onPressed: null),
          ),
        ),
      );

      await tester.tap(find.byType(RoundIconButton));
      await tester.pump();

      expect(find.byType(RoundIconButton), findsOneWidget);
    });

    testWidgets('in the page body the circle is 25 + 12 on a Redmi', (
      tester,
    ) async {
      setRedmi(tester);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Center(
              child: RoundIconButton(
                icon: Icons.person_rounded,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(RoundIconCircle));
      expect(size, const Size(37, 37));
      expect(tester.getSize(find.byIcon(Icons.person_rounded)).width, 25);
    });

    testWidgets('in the top bar the circle is 26 + 12 on a Redmi', (
      tester,
    ) async {
      setRedmi(tester);
      await tester.pumpWidget(
        app(
          Scaffold(
            appBar: AppBar(
              actions: [
                RoundIconButton(icon: Icons.person_rounded, onPressed: () {}),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(RoundIconCircle));
      expect(size, const Size(38, 38));
    });

    testWidgets('in the top bar the circle is 28 + 12 on a Realme', (
      tester,
    ) async {
      setRealme(tester);
      await tester.pumpWidget(
        app(
          Scaffold(
            appBar: AppBar(
              actions: [
                RoundIconButton(icon: Icons.person_rounded, onPressed: () {}),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(RoundIconCircle));
      expect(size, const Size(40, 40));
    });
  });

  group('back button from the theme', () {
    testWidgets('is a rounded arrow in a soft circle', (tester) async {
      setRedmi(tester);
      await tester.pumpWidget(app(const FirstPage()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);

      final circle = find.ancestor(
        of: find.byIcon(Icons.arrow_back_rounded),
        matching: find.byType(RoundIconCircle),
      );
      expect(circleOf(tester, circle).color, AppTheme.softOrange);
      expect(tester.getSize(circle), const Size(38, 38));
    });

    testWidgets('is bigger on a Realme', (tester) async {
      setRealme(tester);
      await tester.pumpWidget(app(const FirstPage()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(RoundIconCircle)), const Size(40, 40));
    });

    testWidgets('still goes back when tapped', (tester) async {
      setRedmi(tester);
      await tester.pumpWidget(app(const FirstPage()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Second page'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Second page'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });
  });
}