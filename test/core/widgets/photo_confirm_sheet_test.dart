import 'package:ada_rasa_foods/core/widgets/photo_confirm_sheet.dart';
import 'package:ada_rasa_foods/features/menu/domain/photo_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const pickedPath = '/cache/picked.jpg';

void main() {
  // Each test opens the sheet and keeps what it gives back.
  late List<PhotoChoice> results;

  setUp(() => results = []);

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                results.add(await showPhotoConfirmSheet(context, pickedPath));
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the photo, the question, and 3 buttons',
      (tester) async {
    await openSheet(tester);

    expect(find.byType(PhotoConfirmSheet), findsOneWidget);
    expect(find.text('Use this photo?'), findsOneWidget);
    expect(find.byKey(const Key('confirm-photo')), findsOneWidget);
    expect(find.text('Customers will see this photo.'), findsOneWidget);
    expect(find.text('Use photo'), findsOneWidget);
    expect(find.text('Pick another'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('Use photo gives use and closes', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Use photo'));
    await tester.pumpAndSettle();

    expect(results, [PhotoChoice.use]);
    expect(find.byType(PhotoConfirmSheet), findsNothing);
  });

  testWidgets('Pick another gives pickAnother', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Pick another'));
    await tester.pumpAndSettle();

    expect(results, [PhotoChoice.pickAnother]);
  });

  testWidgets('Cancel gives cancel', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(results, [PhotoChoice.cancel]);
  });

  testWidgets('tapping outside the sheet counts as cancel', (tester) async {
    await openSheet(tester);

    // The top of the screen is the dark area above the sheet.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(results, [PhotoChoice.cancel]);
    expect(find.byType(PhotoConfirmSheet), findsNothing);
  });

  testWidgets('the phone back button counts as cancel', (tester) async {
    await openSheet(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(results, [PhotoChoice.cancel]);
    expect(find.byType(PhotoConfirmSheet), findsNothing);
  });
}