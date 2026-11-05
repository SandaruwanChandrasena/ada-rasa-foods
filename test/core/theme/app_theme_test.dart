import 'package:ada_rasa_foods/core/theme/app_sizes.dart';
import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Reads the theme that AppThemeByWidth gives at this screen width.
Future<ThemeData> themeAtWidth(WidgetTester tester, double width) async {
  late ThemeData theme;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: AppThemeByWidth(
        child: Builder(
          builder: (context) {
            theme = Theme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return theme;
}

// A small screen with one icon in the top bar and one in the body.
Widget testScreen() {
  return MaterialApp(
    builder: (context, child) => AppThemeByWidth(child: child!),
    home: Scaffold(
      appBar: AppBar(
        title: const Text('My cards'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          const Icon(Icons.star),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
    ),
  );
}

// Sets the test screen to a real phone size, in pixels.
void setPhone(WidgetTester tester, Size pixels, double ratio) {
  tester.view.physicalSize = pixels;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
}

void main() {
  group('AppTheme.light', () {
    final theme = AppTheme.light();

    test('keeps the brand orange and a white page', () {
      expect(theme.colorScheme.primary, AppTheme.brandOrange);
      expect(theme.colorScheme.surface, Colors.white);
      expect(theme.scaffoldBackgroundColor, Colors.white);
    });

    test('the top bar is white, flat, with a centred title', () {
      final bar = theme.appBarTheme;

      expect(bar.backgroundColor, Colors.white);
      expect(bar.foregroundColor, AppTheme.textDark);
      expect(bar.centerTitle, isTrue);
      expect(bar.elevation, 0);
      expect(bar.scrolledUnderElevation, 0);
    });

    test('uses the normal icon sizes when none are given', () {
      expect(theme.appBarTheme.iconTheme?.size, 26);
      expect(theme.appBarTheme.actionsIconTheme?.size, 26);
      expect(theme.iconTheme.size, 25);
      expect(theme.iconButtonTheme.style?.iconSize?.resolve({}), 25);
    });

    test('uses the icon sizes it is given', () {
      final large = AppTheme.light(iconSizes: AppIconSizes.large);

      expect(large.appBarTheme.iconTheme?.size, 28);
      expect(large.appBarTheme.actionsIconTheme?.size, 28);
      expect(large.iconTheme.size, 26);
      expect(large.iconButtonTheme.style?.iconSize?.resolve({}), 26);
    });

    test('text boxes have a light grey border and turn orange on focus', () {
      final fields = theme.inputDecorationTheme;
      final enabled = fields.enabledBorder! as OutlineInputBorder;
      final focused = fields.focusedBorder! as OutlineInputBorder;

      expect(enabled.borderSide.color, AppTheme.border);
      expect(enabled.borderRadius, BorderRadius.circular(12));
      expect(focused.borderSide.color, AppTheme.brandOrange);
      expect(focused.borderSide.width, 1.5);
    });

    test('text boxes with an error have a red border', () {
      final fields = theme.inputDecorationTheme;
      final error = fields.errorBorder! as OutlineInputBorder;

      expect(error.borderSide.color, theme.colorScheme.error);
    });

    test('cards are flat with a light border and round corners', () {
      final card = theme.cardTheme;
      final shape = card.shape! as RoundedRectangleBorder;

      expect(card.elevation, 0);
      expect(shape.side.color, AppTheme.border);
      expect(shape.borderRadius, BorderRadius.circular(16));
    });

    test('FilledButton is still full width and 52 high', () {
      final style = theme.filledButtonTheme.style!;

      expect(style.minimumSize?.resolve({}), const Size.fromHeight(52));
    });

    test('OutlinedButton has a light border', () {
      final style = theme.outlinedButtonTheme.style!;

      expect(style.side?.resolve({})?.color, AppTheme.border);
    });
  });

  group('AppThemeByWidth', () {
    testWidgets('a small phone gets small icons', (tester) async {
      final theme = await themeAtWidth(tester, 320);

      expect(theme.appBarTheme.iconTheme?.size, 24);
      expect(theme.iconTheme.size, 24);
    });

    testWidgets('a normal phone gets normal icons', (tester) async {
      final theme = await themeAtWidth(tester, 392.7);

      expect(theme.appBarTheme.iconTheme?.size, 26);
      expect(theme.iconTheme.size, 25);
    });

    testWidgets('a wide phone gets large icons', (tester) async {
      final theme = await themeAtWidth(tester, 412);

      expect(theme.appBarTheme.iconTheme?.size, 28);
      expect(theme.iconTheme.size, 26);
    });

    testWidgets('icons are drawn at the right size on a Redmi screen', (
      tester,
    ) async {
      // 1080 x 2400 pixels at 2.75 is about 393 points wide.
      setPhone(tester, const Size(1080, 2400), 2.75);
      await tester.pumpWidget(testScreen());

      final cart = find.byIcon(Icons.shopping_cart_outlined);
      expect(tester.getSize(cart), const Size(26, 26));
      expect(tester.getSize(find.byIcon(Icons.star)), const Size(25, 25));
      expect(
        tester.getSize(find.byIcon(Icons.more_vert)),
        const Size(25, 25),
      );
    });

    testWidgets('icons are smaller on a small phone', (tester) async {
      // 640 x 1136 pixels at 2.0 is 320 points wide.
      setPhone(tester, const Size(640, 1136), 2);
      await tester.pumpWidget(testScreen());

      final cart = find.byIcon(Icons.shopping_cart_outlined);
      expect(tester.getSize(cart), const Size(24, 24));
      expect(tester.getSize(find.byIcon(Icons.star)), const Size(24, 24));
    });

    testWidgets('the top bar title is centred', (tester) async {
      setPhone(tester, const Size(1080, 2400), 2.75);
      await tester.pumpWidget(testScreen());

      final screenWidth = tester.view.physicalSize.width / 2.75;
      final title = tester.getCenter(find.text('My cards'));
      expect(title.dx, moreOrLessEquals(screenWidth / 2, epsilon: 1));
    });
  });
}