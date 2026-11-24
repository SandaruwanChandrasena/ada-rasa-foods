import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/photo_header.dart';
import 'package:ada_rasa_foods/core/widgets/round_icon_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// A page with the header, a long list, and a page under it to go back to.
class HeaderPage extends StatelessWidget {
  const HeaderPage({super.key, this.title = 'Kottu Corner'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          PhotoHeader(
            title: title,
            photo: const ColoredBox(color: Colors.brown),
            trailing: (style) => RoundIconButton(
              icon: Icons.shopping_cart_rounded,
              tooltip: 'Cart',
              style: style,
              onPressed: () {},
            ),
          ),
          SliverList.list(
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 80, child: Text('Dish $i')),
            ],
          ),
        ],
      ),
    );
  }
}

void main() {
  Future<void> show(WidgetTester tester, {String? title}) async {
    // Redmi size: about 393 points wide.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AppThemeByWidth(child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => title == null
                        ? const HeaderPage()
                        : HeaderPage(title: title),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollBy(WidgetTester tester, double pixels) async {
    final list = tester.state<ScrollableState>(find.byType(Scrollable));
    list.position.jumpTo(pixels);
    await tester.pump();
  }

  RoundIconStyle styleOf(WidgetTester tester, String tooltip) {
    return tester
        .widget<RoundIconCircle>(
          find.descendant(
            of: find.byTooltip(tooltip),
            matching: find.byType(RoundIconCircle),
          ),
        )
        .style;
  }

  // The header's box (the header itself is a sliver, not a box).
  Size headerSize(WidgetTester tester) {
    return tester.getSize(
      find
          .descendant(
            of: find.byType(PhotoHeader),
            matching: find.byType(Stack),
          )
          .first,
    );
  }

  double titleAlpha(WidgetTester tester) {
    final title = tester.widget<Text>(find.text('Kottu Corner'));
    return title.style!.color!.a;
  }

  double whiteLayerAlpha(WidgetTester tester) {
    final layer = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(PhotoHeader),
        matching: find.byWidgetPredicate(
          (w) =>
              w is ColoredBox &&
              w.color.r == 1 &&
              w.color.g == 1 &&
              w.color.b == 1,
        ),
      ),
    );
    return layer.color.a;
  }

  group('PhotoHeader', () {
    testWidgets('opens with the full photo and white circle buttons', (
      tester,
    ) async {
      await show(tester);

      expect(styleOf(tester, 'Back'), RoundIconStyle.onPhoto);
      expect(styleOf(tester, 'Cart'), RoundIconStyle.onPhoto);
      expect(whiteLayerAlpha(tester), 0);
      expect(titleAlpha(tester), 0);
    });

    testWidgets('the photo is 220 high when open', (tester) async {
      await show(tester);

      expect(headerSize(tester).height, 220);
    });

    testWidgets('a little scroll keeps the white buttons', (tester) async {
      await show(tester);

      await scrollBy(tester, 50);

      expect(styleOf(tester, 'Back'), RoundIconStyle.onPhoto);
      expect(titleAlpha(tester), 0);
      expect(whiteLayerAlpha(tester), greaterThan(0));
    });

    testWidgets('scrolled up, it is a white bar with the title', (
      tester,
    ) async {
      await show(tester);

      await scrollBy(tester, 400);

      expect(styleOf(tester, 'Back'), RoundIconStyle.soft);
      expect(styleOf(tester, 'Cart'), RoundIconStyle.soft);
      expect(whiteLayerAlpha(tester), 1);
      expect(titleAlpha(tester), 1);
    });

    testWidgets('the white bar is a normal top bar height', (tester) async {
      await show(tester);

      await scrollBy(tester, 400);

      expect(headerSize(tester).height, kToolbarHeight);
    });

    testWidgets('scrolling back down shows the photo again', (tester) async {
      await show(tester);
      await scrollBy(tester, 400);

      await scrollBy(tester, 0);

      expect(styleOf(tester, 'Back'), RoundIconStyle.onPhoto);
      expect(titleAlpha(tester), 0);
    });

    testWidgets('the back button goes back', (tester) async {
      await show(tester);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(HeaderPage), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('top bar icons use the bar size (26 on a Redmi)', (
      tester,
    ) async {
      await show(tester);

      final back = tester.getSize(find.byIcon(Icons.arrow_back_rounded));
      expect(back, const Size(26, 26));
    });

    testWidgets('a very long title fits with no overflow', (tester) async {
      await show(
        tester,
        title: 'The Very Famous Original Colombo Kottu and Rice Corner',
      );
      await scrollBy(tester, 400);

      expect(tester.takeException(), isNull);
    });
  });
}