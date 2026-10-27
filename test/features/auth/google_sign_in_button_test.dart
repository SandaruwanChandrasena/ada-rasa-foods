import 'package:ada_rasa_foods/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shows the label and calls onPressed', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleSignInButton(onPressed: () => tapped = true),
        ),
      ),
    );

    expect(find.text('Continue with Google'), findsOneWidget);

    await tester.tap(find.byType(GoogleSignInButton));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('is disabled when onPressed is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GoogleSignInButton(onPressed: null)),
      ),
    );

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
  });
}