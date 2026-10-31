import 'package:ada_rasa_foods/features/payments/domain/card_brand.dart';
import 'package:ada_rasa_foods/features/payments/domain/card_repository.dart';
import 'package:ada_rasa_foods/features/payments/domain/payment_card.dart';
import 'package:ada_rasa_foods/features/payments/presentation/add_card_screen.dart';
import 'package:ada_rasa_foods/features/payments/presentation/card_preview.dart';
import 'package:ada_rasa_foods/features/payments/presentation/cards_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockCardRepository extends Mock implements CardRepository {}

// The 3 text boxes, in page order.
final numberField = find.byType(TextField).at(0);
final nameField = find.byType(TextField).at(1);
final cvvField = find.byType(TextField).at(2);

String textOf(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.text;

void main() {
  late MockCardRepository repository;
  late CardsCubit cubit;

  setUpAll(() {
    registerFallbackValue(
      const PaymentCard(
        brand: CardBrand.visa,
        last4: '0000',
        holderName: 'X',
        expMonth: 1,
        expYear: 2000,
      ),
    );
  });

  setUp(() {
    repository = MockCardRepository();
    when(() => repository.watchCards(any()))
        .thenAnswer((_) => Stream.value(const []));
    when(() => repository.addCard(any(), any())).thenAnswer((_) async {});
    cubit = CardsCubit(repository)..start('u1');
  });

  tearDown(() => cubit.close());

  // Opens a home screen with a button, then the Add card screen on top.
  // So we can check that a good save closes the screen.
  Future<void> openScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<CardsCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => const AddCardView(),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  // Picks a value in the month or year menu.
  Future<void> pick(WidgetTester tester, String box, String value) async {
    await tester.tap(find.text(box));
    await tester.pumpAndSettle();
    await tester.tap(find.text(value).last);
    await tester.pumpAndSettle();
  }

  final nextYear = '${DateTime.now().year + 2}';

  testWidgets('opens with an empty card and the form', (tester) async {
    await openScreen(tester);

    expect(find.text('Add card'), findsOneWidget);
    expect(find.text('Card Number'), findsOneWidget);
    expect(find.text('Card Holder'), findsNWidgets(2)); // form + card
    expect(find.text('Save card'), findsOneWidget);
    expect(find.text('#'), findsNWidgets(16));
    expect(find.text('FULL NAME'), findsOneWidget);
  });

  testWidgets('the number gets spaces and stops at 16 digits',
      (tester) async {
    await openScreen(tester);

    await tester.enterText(numberField, '42424242424242429999');
    await tester.pumpAndSettle();

    expect(textOf(tester, numberField), '4242 4242 4242 4242');
    expect(find.text('#'), findsNothing);
    expect(find.text('*'), findsNWidgets(8));
  });

  testWidgets('the name becomes capitals, with no numbers', (tester) async {
    await openScreen(tester);

    await tester.enterText(nameField, 'nimal perera7');
    await tester.pumpAndSettle();

    expect(textOf(tester, nameField), 'NIMAL PERERA');
    expect(find.text('FULL NAME'), findsNothing);
  });

  testWidgets('the CVV takes 3 digits and flips the card', (tester) async {
    await openScreen(tester);

    await tester.enterText(cvvField, '12a34');
    await tester.pumpAndSettle();

    expect(textOf(tester, cvvField), '123');
    final preview = tester.widget<CardPreview>(find.byType(CardPreview));
    expect(preview.isFlipped, isTrue);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final after = tester.widget<CardPreview>(find.byType(CardPreview));
    expect(after.isFlipped, isFalse);
  });

  testWidgets('Save with an empty form shows every error', (tester) async {
    await openScreen(tester);

    await tester.ensureVisible(find.text('Save card'));
    await tester.tap(find.text('Save card'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the card number.'), findsOneWidget);
    expect(find.text('Enter the name on the card.'), findsOneWidget);
    expect(find.text('Choose the month and year.'), findsOneWidget);
    expect(find.text('The CVV must have 3 digits.'), findsOneWidget);
    verifyNever(() => repository.addCard(any(), any()));
  });

  testWidgets('a number that fails Luhn shows an error', (tester) async {
    await openScreen(tester);

    await tester.enterText(numberField, '4242424242424241');
    await tester.ensureVisible(find.text('Save card'));
    await tester.tap(find.text('Save card'));
    await tester.pumpAndSettle();

    expect(find.text('This card number is not valid.'), findsOneWidget);
    verifyNever(() => repository.addCard(any(), any()));
  });

  testWidgets('a good card is saved and the screen closes', (tester) async {
    await openScreen(tester);

    await tester.enterText(numberField, '4242424242424242');
    await tester.enterText(nameField, 'Nimal Perera');
    await tester.enterText(cvvField, '123');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Year'));
    await pick(tester, 'Year', nextYear);
    await pick(tester, 'Month', '02');

    await tester.ensureVisible(find.text('Save card'));
    await tester.tap(find.text('Save card'));
    await tester.pumpAndSettle();

    final card = verify(() => repository.addCard('u1', captureAny()))
        .captured
        .single as PaymentCard;
    expect(card.brand, CardBrand.visa);
    expect(card.last4, '4242');
    expect(card.holderName, 'NIMAL PERERA');
    expect(card.expMonth, 2);
    expect(card.expYear, int.parse(nextYear));

    // Back on the first screen.
    expect(find.text('Save card'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('the CVV box shows dots, not the digits', (tester) async {
    await openScreen(tester);

    await tester.enterText(cvvField, '123');
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(cvvField);
    expect(field.obscureText, isTrue);
    expect(field.obscuringCharacter, '•');
    // The digits are still kept, so they can be checked.
    expect(textOf(tester, cvvField), '123');
  });

  testWidgets('the card waits until the page has slid in', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<CardsCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<bool>(
                    builder: (_) => const AddCardView(),
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
    await tester.pump();

    // The card fades in, so read the Opacity just above it.
    double cardOpacity() => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byType(CardPreview),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    // While the page is still sliding in, the card is not shown yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect(cardOpacity(), 0);

    // When everything is done, the card is fully shown.
    await tester.pumpAndSettle();
    expect(cardOpacity(), 1);
  });
}