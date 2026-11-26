import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/status_strip.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    double statusBar = 24,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          viewPadding: EdgeInsets.only(top: statusBar),
          padding: EdgeInsets.only(top: statusBar),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: StatusStrip(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  Finder strip() => find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == AppTheme.statusBarColor,
      );

  testWidgets('paints an orange strip as tall as the status bar',
      (tester) async {
    await show(tester);

    expect(strip(), findsOneWidget);
    // As wide as the page, at the very top.
    final page = tester.getSize(find.byType(StatusStrip));
    expect(tester.getRect(strip()), Rect.fromLTWH(0, 0, page.width, 24));
  });

  testWidgets('asks the phone for white status bar icons', (tester) async {
    await show(tester);

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(region.value, AppTheme.statusBarStyle);
    expect(region.value.statusBarIconBrightness, Brightness.light);
  });

  testWidgets('the strip is the brand orange', (tester) async {
    await show(tester);

    expect(AppTheme.statusBarColor, AppTheme.brandOrange);
  });

  testWidgets('with no status bar, the strip has no height', (tester) async {
    await show(tester, statusBar: 0);

    expect(tester.getSize(strip()).height, 0);
  });

  testWidgets('a tap on the strip still reaches the page under it',
      (tester) async {
    var taps = 0;
    await show(tester, onTap: () => taps++);

    await tester.tapAt(const Offset(200, 10));

    expect(taps, 1);
  });
}