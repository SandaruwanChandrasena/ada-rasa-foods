import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ada_rasa_foods/main.dart';

void main() {
  // We test only the screen, not the full app.
  // This is because tests run on your computer, not on a phone,
  // so they cannot connect to the real Firebase.
  testWidgets('Firebase check screen shows app name and project ID',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FirebaseCheckScreen(projectId: 'test-project'),
      ),
    );

    expect(find.text('Ada Rasa'), findsOneWidget);
    expect(find.text('Firebase connected'), findsOneWidget);
    expect(find.text('Project: test-project'), findsOneWidget);
  });
}