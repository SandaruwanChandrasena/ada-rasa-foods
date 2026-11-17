import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/customer_bottom_bar.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Redmi: about 393 points wide (normal icons).
void setRedmi(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

// Realme: about 424 points wide (large icons).
void setRealme(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 1.7;
  addTearDown(tester.view.reset);
}

Color? iconColor(WidgetTester tester, IconData icon) {
  return IconTheme.of(tester.element(find.byIcon(icon))).color;
}

// find.byTooltip cannot see bottom bar tooltips, so match them directly.
Finder tabTooltip(String message) {
  return find.byWidgetPredicate((w) => w is Tooltip && w.message == message);
}

Color? labelColor(WidgetTester tester, String label) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
  return paragraph.text.style?.color;
}

void main() {
  late List<int> taps;

  setUp(() => taps = []);

  Future<void> show(
    WidgetTester tester, {
    int currentIndex = CustomerBottomBar.home,
    bool showOrdersDot = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AppThemeByWidth(child: child!),
        home: Scaffold(
          bottomNavigationBar: CustomerBottomBar(
            currentIndex: currentIndex,
            onTap: taps.add,
            showOrdersDot: showOrdersDot,
          ),
        ),
      ),
    );
  }

  Badge ordersBadge(WidgetTester tester) {
    return tester.widget<Badge>(
      find.ancestor(
        of: find.byIcon(Icons.receipt_long_rounded),
        matching: find.byType(Badge),
      ),
    );
  }

  group('CustomerBottomBar', () {
    testWidgets('shows Home, Orders and Profile with rounded icons', (
      tester,
    ) async {
      setRedmi(tester);
      await show(tester);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('the open tab is orange and the others are grey', (
      tester,
    ) async {
      setRedmi(tester);
      await show(tester);

      expect(iconColor(tester, Icons.home_rounded), AppTheme.brandOrange);
      expect(labelColor(tester, 'Home'), AppTheme.brandOrange);
      expect(iconColor(tester, Icons.person_rounded), AppTheme.textMuted);
      expect(labelColor(tester, 'Profile'), AppTheme.textMuted);
    });

    testWidgets('opening Profile makes Profile orange and Home grey', (
      tester,
    ) async {
      setRedmi(tester);
      await show(tester, currentIndex: CustomerBottomBar.profile);
      await tester.pumpAndSettle();

      expect(iconColor(tester, Icons.person_rounded), AppTheme.brandOrange);
      expect(iconColor(tester, Icons.home_rounded), AppTheme.textMuted);
    });

    testWidgets('icons are 25 on a Redmi', (tester) async {
      setRedmi(tester);
      await show(tester);

      final size = tester.getSize(find.byIcon(Icons.home_rounded));
      expect(size, const Size(25, 25));
    });

    testWidgets('icons are 26 on a Realme', (tester) async {
      setRealme(tester);
      await show(tester);

      final size = tester.getSize(find.byIcon(Icons.home_rounded));
      expect(size, const Size(26, 26));
    });

    testWidgets('tapping a tab sends its number', (tester) async {
      setRedmi(tester);
      await show(tester);

      await tester.tap(find.text('Orders'));
      await tester.tap(find.text('Profile'));
      await tester.pump();

      expect(taps, [CustomerBottomBar.orders, CustomerBottomBar.profile]);
    });

    testWidgets('tapping the open tab also sends its number', (tester) async {
      setRedmi(tester);
      await show(tester);

      await tester.tap(find.text('Home'));
      await tester.pump();

      expect(taps, [CustomerBottomBar.home]);
    });

    testWidgets('no dot on Orders when no order is going', (tester) async {
      setRedmi(tester);
      await show(tester);

      expect(ordersBadge(tester).isLabelVisible, isFalse);
      expect(tabTooltip('Orders'), findsOneWidget);
    });

    testWidgets('an orange dot on Orders while an order is going', (
      tester,
    ) async {
      setRedmi(tester);
      await show(tester, showOrdersDot: true);

      final badge = ordersBadge(tester);
      expect(badge.isLabelVisible, isTrue);
      expect(badge.backgroundColor, AppTheme.brandOrange);
      expect(badge.label, isNull);
      expect(tabTooltip('Orders, one is still going'), findsOneWidget);
    });

    testWidgets('has a light line on top', (tester) async {
      setRedmi(tester);
      await show(tester);

      final box = tester.widget<DecoratedBox>(
        find.ancestor(
          of: find.byType(NavigationBar),
          matching: find.byType(DecoratedBox),
        ).first,
      );
      final border = (box.decoration as BoxDecoration).border! as Border;
      expect(border.top.color, AppTheme.border);
    });
  });
}