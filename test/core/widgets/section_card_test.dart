import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/section_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> show(WidgetTester tester, Widget card) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: card),
        ),
      ),
    );
  }

  group('SectionCard', () {
    testWidgets('shows the icon, the title and the content', (tester) async {
      await show(
        tester,
        const SectionCard(
          icon: Icons.payments_rounded,
          title: 'Payment',
          child: Text('Pay at pickup'),
        ),
      );

      expect(find.byIcon(Icons.payments_rounded), findsOneWidget);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Pay at pickup'), findsOneWidget);
    });

    testWidgets('the title is bold and the content is below it', (
      tester,
    ) async {
      await show(
        tester,
        const SectionCard(
          icon: Icons.payments_rounded,
          title: 'Payment',
          child: Text('Pay at pickup'),
        ),
      );

      final title = tester.widget<Text>(find.text('Payment'));
      expect(title.style?.fontWeight, FontWeight.w700);
      final titleBottom = tester.getBottomLeft(find.text('Payment')).dy;
      final contentTop = tester.getTopLeft(find.text('Pay at pickup')).dy;
      expect(contentTop, greaterThan(titleBottom));
    });

    testWidgets('the icon is white on an orange rounded square', (
      tester,
    ) async {
      await show(
        tester,
        const SectionCard(
          icon: Icons.call_rounded,
          title: 'Contact',
          child: SizedBox(),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.call_rounded));
      expect(icon.color, Colors.white);
      final box = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.call_rounded),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, AppTheme.brandOrange);
      expect(tester.getSize(find.byType(SectionIcon)), const Size(30, 30));
    });

    testWidgets('a trailing button sits on the right of the title', (
      tester,
    ) async {
      await show(
        tester,
        SectionCard(
          icon: Icons.call_rounded,
          title: 'Contact',
          trailing: TextButton(onPressed: () {}, child: const Text('Change')),
          child: const Text('071 234 5678'),
        ),
      );

      final title = tester.getCenter(find.text('Contact'));
      final change = tester.getCenter(find.text('Change'));
      expect(change.dx, greaterThan(title.dx));
      expect((change.dy - title.dy).abs(), lessThan(12));
    });

    testWidgets('it is a flat card with no outside margin', (tester) async {
      await show(
        tester,
        const SectionCard(
          icon: Icons.call_rounded,
          title: 'Contact',
          child: SizedBox(),
        ),
      );

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.margin, EdgeInsets.zero);
    });

    testWidgets('SectionIcon can be bigger', (tester) async {
      await show(
        tester,
        const Center(
          child: SectionIcon(icon: Icons.storefront_rounded, size: 40),
        ),
      );

      expect(tester.getSize(find.byType(SectionIcon)), const Size(40, 40));
      final icon = tester.widget<Icon>(find.byIcon(Icons.storefront_rounded));
      expect(icon.size, 24);
    });
  });
}