import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/open_status_chip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> show(WidgetTester tester, {required bool isOpen}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: OpenStatusChip(isOpen: isOpen)),
        ),
      ),
    );
  }

  Color? textColor(WidgetTester tester, String text) {
    return tester.widget<Text>(find.text(text)).style?.color;
  }

  group('OpenStatusChip', () {
    testWidgets('open: green "Open" with a tick', (tester) async {
      await show(tester, isOpen: true);

      expect(find.text('Open'), findsOneWidget);
      expect(textColor(tester, 'Open'), AppTheme.successGreen);
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
      expect(icon.color, AppTheme.successGreen);
    });

    testWidgets('closed: red "Closed" with a cross', (tester) async {
      await show(tester, isOpen: false);

      expect(find.text('Closed'), findsOneWidget);
      expect(textColor(tester, 'Closed'), AppTheme.dangerRed);
      final icon = tester.widget<Icon>(find.byIcon(Icons.cancel_rounded));
      expect(icon.color, AppTheme.dangerRed);
    });

    testWidgets('is a white pill, so it shows on any photo', (tester) async {
      await show(tester, isOpen: true);

      final pill = tester.widget<Container>(
        find
            .ancestor(of: find.text('Open'), matching: find.byType(Container))
            .first,
      );
      final box = pill.decoration! as BoxDecoration;
      expect(box.color, Colors.white);
      expect(box.borderRadius, BorderRadius.circular(20));
    });
  });
}