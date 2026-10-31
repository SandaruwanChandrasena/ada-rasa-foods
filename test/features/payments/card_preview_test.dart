import 'package:ada_rasa_foods/features/payments/domain/card_brand.dart';
import 'package:ada_rasa_foods/features/payments/presentation/card_art.dart';
import 'package:ada_rasa_foods/features/payments/presentation/card_preview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Shows the card at about phone width and waits for the animations.
Future<void> showCard(
  WidgetTester tester, {
  String number = '',
  String name = '',
  String month = '',
  String year = '',
  String cvv = '',
  bool flipped = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 340,
            height: 214,
            child: CardPreview(
              cardNumber: number,
              cardName: name,
              cardMonth: month,
              cardYear: year,
              cardCvv: cvv,
              isFlipped: flipped,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// The brand the logo shows, or null for no logo.
CardBrand? logoBrand(WidgetTester tester) {
  return tester.widget<CardBrandLogo>(find.byType(CardBrandLogo).first).brand;
}

// True if the card side that holds [inside] is showing.
bool sideVisible(WidgetTester tester, Finder inside) {
  final side = find.ancestor(of: inside, matching: find.byType(Visibility));
  return tester.widget<Visibility>(side.first).visible;
}

void main() {
  testWidgets('an empty card shows the placeholders', (tester) async {
    await showCard(tester);

    expect(find.text('#'), findsNWidgets(16));
    expect(find.text('FULL NAME'), findsOneWidget);
    expect(find.text('MM'), findsOneWidget);
    expect(find.text('YY'), findsOneWidget);
    expect(logoBrand(tester), isNull);
  });

  testWidgets('a Visa number shows VISA and hides the middle 8 digits',
      (tester) async {
    await showCard(tester, number: '4242 4242 4242 4242');

    expect(find.text('#'), findsNothing);
    expect(find.text('*'), findsNWidgets(8));
    expect(find.text('VISA'), findsWidgets);
    expect(logoBrand(tester), CardBrand.visa);
  });

  testWidgets('a Mastercard number shows the Mastercard logo',
      (tester) async {
    await showCard(tester, number: '5555 5555 5555 4444');

    expect(logoBrand(tester), CardBrand.mastercard);
    expect(find.text('VISA'), findsNothing);
  });

  testWidgets('another card type shows no logo', (tester) async {
    await showCard(tester, number: '6011 1111 1111 1117');

    expect(logoBrand(tester), isNull);
    expect(find.text('VISA'), findsNothing);
  });

  testWidgets('a part number keeps # for the missing digits',
      (tester) async {
    await showCard(tester, number: '4242 42');

    // 6 digits typed, so 10 slots still show #.
    // Digits 5 and 6 are in the hidden middle part.
    expect(find.text('#'), findsNWidgets(10));
    expect(find.text('*'), findsNWidgets(2));
  });

  testWidgets('the name and date show on the card', (tester) async {
    await showCard(tester, name: 'NIMAL', month: '08', year: '2028');

    expect(find.text('FULL NAME'), findsNothing);
    expect(find.text('N'), findsOneWidget);
    expect(find.text('08'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
  });

  testWidgets('the card flips to the back for the CVV, and back again',
      (tester) async {
    await showCard(tester, cvv: '123');
    expect(sideVisible(tester, find.text('FULL NAME')), isTrue);

    await showCard(tester, cvv: '123', flipped: true);
    expect(sideVisible(tester, find.text('FULL NAME')), isFalse);
    expect(sideVisible(tester, find.text('CVV')), isTrue);
    expect(find.text('*'), findsNWidgets(3));

    await showCard(tester, cvv: '123');
    expect(sideVisible(tester, find.text('FULL NAME')), isTrue);
  });
}