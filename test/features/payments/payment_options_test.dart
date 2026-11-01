import 'package:ada_rasa_foods/features/payments/domain/card_brand.dart';
import 'package:ada_rasa_foods/features/payments/domain/payment_card.dart';
import 'package:ada_rasa_foods/features/payments/presentation/cards_state.dart';
import 'package:ada_rasa_foods/features/payments/presentation/payment_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

PaymentCard card(
  String id,
  String last4, {
  CardBrand brand = CardBrand.visa,
  bool isDefault = false,
  int expMonth = 8,
  int expYear = 2030,
}) {
  return PaymentCard(
    id: id,
    brand: brand,
    last4: last4,
    holderName: 'NIMAL PERERA',
    expMonth: expMonth,
    expYear: expYear,
    isDefault: isDefault,
  );
}

final now = DateTime(2026, 11, 1);
final visa = card('c1', '4242', isDefault: true);
final master = card('c2', '4444', brand: CardBrand.mastercard);
final failing = card('c3', '0002');
final expired = card('c4', '1111', expMonth: 9, expYear: 2026);

CardsState loaded(List<PaymentCard> cards) =>
    CardsState(status: CardsStatus.loaded, cards: cards);

// True when the row with this text shows the orange tick.
bool isTicked(WidgetTester tester, String title) {
  final row = find.ancestor(
    of: find.text(title),
    matching: find.byType(InkWell),
  );
  final ticks = find.descendant(
    of: row,
    matching: find.byIcon(Icons.check_circle),
  );
  return ticks.evaluate().isNotEmpty;
}

void main() {
  late List<PaymentCard?> picked;
  late int retries;
  late int manageTaps;

  setUp(() {
    picked = [];
    retries = 0;
    manageTaps = 0;
  });

  Future<void> show(
    WidgetTester tester, {
    required CardsState cards,
    PaymentCard? selected,
    bool enabled = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PaymentOptions(
              cards: cards,
              now: now,
              selected: selected,
              onSelected: picked.add,
              onRetry: () => retries++,
              onManageCards: () => manageTaps++,
              enabled: enabled,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows cash first, then the saved cards', (tester) async {
    await show(tester, cards: loaded([visa, master]), selected: visa);

    final cashY = tester.getTopLeft(find.text('Cash at pickup')).dy;
    final visaY = tester.getTopLeft(find.text('Visa ending 4242')).dy;
    final masterY =
        tester.getTopLeft(find.text('Mastercard ending 4444')).dy;

    expect(cashY, lessThan(visaY));
    expect(visaY, lessThan(masterY));
    expect(find.text('Expires 08/30'), findsNWidgets(2));
  });

  testWidgets('only the selected row has the orange tick', (tester) async {
    await show(tester, cards: loaded([visa, master]), selected: visa);

    expect(isTicked(tester, 'Visa ending 4242'), isTrue);
    expect(isTicked(tester, 'Cash at pickup'), isFalse);
    expect(isTicked(tester, 'Mastercard ending 4444'), isFalse);
  });

  testWidgets('null selected means cash is ticked', (tester) async {
    await show(tester, cards: loaded([visa]));

    expect(isTicked(tester, 'Cash at pickup'), isTrue);
    expect(isTicked(tester, 'Visa ending 4242'), isFalse);
  });

  testWidgets('shows the Default and Always fails labels', (tester) async {
    await show(tester, cards: loaded([visa, failing]), selected: visa);

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Always fails (demo)'), findsOneWidget);
  });

  testWidgets('tapping a card or cash tells the screen', (tester) async {
    await show(tester, cards: loaded([visa, failing]), selected: visa);

    await tester.tap(find.text('Visa ending 0002'));
    await tester.tap(find.text('Cash at pickup'));

    expect(picked, [failing, null]);
  });

  testWidgets('an expired card is faded and cannot be chosen',
      (tester) async {
    await show(tester, cards: loaded([visa, expired]), selected: visa);

    expect(find.text('Expired 09/26'), findsOneWidget);
    final fade = find.ancestor(
      of: find.text('Visa ending 1111'),
      matching: find.byType(Opacity),
    );
    expect(fade, findsOneWidget);

    await tester.tap(find.text('Visa ending 1111'));
    expect(picked, isEmpty);
  });

  testWidgets('shows a loading line while cards load', (tester) async {
    await show(tester, cards: const CardsState());

    expect(find.text('Loading your cards...'), findsOneWidget);
    expect(find.text('Cash at pickup'), findsOneWidget);
  });

  testWidgets('when cards fail, cash stays and Retry works',
      (tester) async {
    await show(
      tester,
      cards: const CardsState(
        status: CardsStatus.failure,
        errorMessage: 'No internet connection.',
      ),
    );

    expect(find.text('Cards could not load.'), findsOneWidget);
    expect(isTicked(tester, 'Cash at pickup'), isTrue);

    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('with no cards, only cash and Manage cards show',
      (tester) async {
    await show(tester, cards: loaded([]));

    expect(find.text('Cash at pickup'), findsOneWidget);
    expect(find.textContaining('ending'), findsNothing);

    await tester.tap(find.text('Manage cards'));
    expect(manageTaps, 1);
  });

  testWidgets('nothing can be tapped while the order is placing',
      (tester) async {
    await show(
      tester,
      cards: loaded([visa, master]),
      selected: visa,
      enabled: false,
    );

    await tester.tap(find.text('Mastercard ending 4444'));
    await tester.tap(find.text('Cash at pickup'));
    await tester.tap(find.text('Manage cards'));

    expect(picked, isEmpty);
    expect(manageTaps, 0);
  });
}