import 'package:ada_rasa_foods/features/orders/presentation/checkout_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late int addTaps;
  late int changeTaps;

  setUp(() {
    addTaps = 0;
    changeTaps = 0;
  });

  Future<void> show(WidgetTester tester, String phone) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CheckoutPhoneBox(
              phone: phone,
              onAddPhone: () => addTaps++,
              onChangePhone: () => changeTaps++,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('no phone asks for one', (tester) async {
    await show(tester, '');

    expect(
      find.text('Add your phone number so the restaurant can call you.'),
      findsOneWidget,
    );
    expect(find.text('Add phone'), findsOneWidget);
    expect(find.text('Change'), findsNothing);
  });

  testWidgets('"Add phone" opens the add phone page', (tester) async {
    await show(tester, '');

    await tester.tap(find.text('Add phone'));

    expect(addTaps, 1);
    expect(changeTaps, 0);
  });

  testWidgets('a saved phone shows in groups, with Change', (tester) async {
    await show(tester, '0712345678');

    expect(find.text('The restaurant may call you at'), findsOneWidget);
    expect(find.text('071 234 5678'), findsOneWidget);
    expect(find.text('Add phone'), findsNothing);

    await tester.tap(find.text('Change'));
    expect(changeTaps, 1);
  });

  testWidgets('a wrong old phone is treated like no phone', (tester) async {
    await show(tester, '0112345678');

    expect(find.text('Add phone'), findsOneWidget);
  });
}