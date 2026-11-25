import 'package:ada_rasa_foods/features/payments/domain/card_brand.dart';
import 'package:ada_rasa_foods/features/payments/domain/payment_card.dart';
import 'package:ada_rasa_foods/features/payments/presentation/card_art.dart';
import 'package:ada_rasa_foods/features/payments/presentation/mini_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

PaymentCard cardOf(CardBrand brand, String last4) {
  return PaymentCard(
    id: 'c1',
    brand: brand,
    last4: last4,
    holderName: 'NIMAL PERERA',
    expMonth: 8,
    expYear: 2030,
  );
}

void main() {
  Future<void> show(WidgetTester tester, PaymentCard card) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: MiniCard(card: card))),
      ),
    );
  }

  testWidgets('a Visa shows the logo and the last 4 digits', (tester) async {
    await show(tester, cardOf(CardBrand.visa, '4242'));

    expect(find.text('VISA'), findsOneWidget);
    expect(find.text('•••• 4242'), findsOneWidget);
  });

  testWidgets('a Mastercard has no VISA text', (tester) async {
    await show(tester, cardOf(CardBrand.mastercard, '4444'));

    expect(find.text('VISA'), findsNothing);
    expect(find.text('•••• 4444'), findsOneWidget);
    expect(find.byType(CardBrandLogo), findsOneWidget);
  });

  testWidgets('uses the card art: dark background and gold chip',
      (tester) async {
    await show(tester, cardOf(CardBrand.visa, '4242'));

    expect(find.byType(CardBackground), findsOneWidget);
    expect(find.byType(CardChip), findsOneWidget);
  });

  testWidgets('is a small 72 x 46 picture', (tester) async {
    await show(tester, cardOf(CardBrand.visa, '4242'));

    expect(tester.getSize(find.byType(MiniCard)), const Size(72, 46));
  });

  testWidgets('screen readers skip it (the row says the card)',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester, cardOf(CardBrand.visa, '4242'));

    expect(find.bySemanticsLabel(RegExp('4242')), findsNothing);
    semantics.dispose();
  });
}