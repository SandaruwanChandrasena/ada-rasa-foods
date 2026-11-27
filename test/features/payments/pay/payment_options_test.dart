import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/features/payments/domain/card_brand.dart';
import 'package:ada_rasa_foods/features/payments/domain/payment_card.dart';
import 'package:ada_rasa_foods/features/payments/presentation/cards/cards_state.dart';
import 'package:ada_rasa_foods/features/payments/presentation/pay/payment_options.dart';
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
final expiredDefault =
    card('c5', '5555', isDefault: true, expMonth: 9, expYear: 2026);

CardsState loaded(List<PaymentCard> cards) =>
    CardsState(status: CardsStatus.loaded, cards: cards);

// True when the tile or row with this text shows the orange tick.
bool isTicked(WidgetTester tester, String text) {
  final box = find.ancestor(
    of: find.text(text),
    matching: find.byType(InkWell),
  );
  final ticks = find.descendant(
    of: box,
    matching: find.byIcon(Icons.check_circle_rounded),
  );
  return ticks.evaluate().isNotEmpty;
}

// The border colour of the Cash or Card tile.
Color tileBorder(WidgetTester tester, String key) {
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Material),
        )
        .first,
  );
  return (material.shape! as RoundedRectangleBorder).side.color;
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
    double width = 1080,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
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

  testWidgets('Cash and Card tiles sit side by side', (tester) async {
    await show(tester, cards: loaded([visa]));

    final cash = tester.getRect(find.byKey(const ValueKey('pay_cash')));
    final cardTile = tester.getRect(find.byKey(const ValueKey('pay_card')));

    expect(cash.top, cardTile.top);
    expect(cash.right, lessThan(cardTile.left));
    expect(find.text('At pickup'), findsOneWidget);
    expect(find.text('Demo card'), findsOneWidget);
  });

  testWidgets('with cash chosen, the Cash tile is orange and no cards show',
      (tester) async {
    await show(tester, cards: loaded([visa, master]));

    expect(isTicked(tester, 'Cash'), isTrue);
    expect(isTicked(tester, 'Card'), isFalse);
    expect(tileBorder(tester, 'pay_cash'), AppTheme.brandOrange);
    expect(tileBorder(tester, 'pay_card'), AppTheme.border);
    expect(find.textContaining('ending'), findsNothing);
  });

  testWidgets('with a card chosen, the Card tile is orange and cards show',
      (tester) async {
    await show(tester, cards: loaded([visa, master]), selected: visa);

    expect(isTicked(tester, 'Card'), isTrue);
    expect(isTicked(tester, 'Cash'), isFalse);
    expect(tileBorder(tester, 'pay_card'), AppTheme.brandOrange);
    expect(tileBorder(tester, 'pay_cash'), AppTheme.border);

    final visaY = tester.getTopLeft(find.text('Visa ending 4242')).dy;
    final masterY =
        tester.getTopLeft(find.text('Mastercard ending 4444')).dy;
    expect(visaY, lessThan(masterY));
    expect(find.text('Expires 08/30'), findsNWidgets(2));
  });

  testWidgets('only the chosen card row has the tick', (tester) async {
    await show(tester, cards: loaded([visa, master]), selected: master);

    expect(isTicked(tester, 'Mastercard ending 4444'), isTrue);
    expect(isTicked(tester, 'Visa ending 4242'), isFalse);
  });

  testWidgets('shows the Default and Always fails labels', (tester) async {
    await show(tester, cards: loaded([visa, failing]), selected: visa);

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Always fails (demo)'), findsOneWidget);
  });

  testWidgets('tapping a card row or the Cash tile tells the screen',
      (tester) async {
    await show(tester, cards: loaded([visa, failing]), selected: visa);

    await tester.tap(find.text('Visa ending 0002'));
    await tester.tap(find.text('Cash'));

    expect(picked, [failing, null]);
  });

  testWidgets('tapping the Card tile picks the default card', (tester) async {
    await show(tester, cards: loaded([master, visa]));

    await tester.tap(find.text('Card'));

    expect(picked, [visa]);
    expect(manageTaps, 0);
  });

  testWidgets('an expired default makes the Card tile pick a usable card',
      (tester) async {
    await show(tester, cards: loaded([expiredDefault, master]));

    await tester.tap(find.text('Card'));

    expect(picked, [master]);
  });

  testWidgets('with no cards, the Card tile opens Manage cards',
      (tester) async {
    await show(tester, cards: loaded([]));

    await tester.tap(find.text('Card'));

    expect(picked, isEmpty);
    expect(manageTaps, 1);
  });

  testWidgets('with only expired cards, the Card tile opens Manage cards',
      (tester) async {
    await show(tester, cards: loaded([expired]));

    await tester.tap(find.text('Card'));

    expect(picked, isEmpty);
    expect(manageTaps, 1);
  });

  testWidgets('tapping the Card tile again does nothing', (tester) async {
    await show(tester, cards: loaded([visa, master]), selected: master);

    await tester.tap(find.text('Card'));

    expect(picked, isEmpty);
    expect(manageTaps, 0);
  });

  testWidgets('an expired card is faded and cannot be chosen',
      (tester) async {
    await show(tester, cards: loaded([visa, expired]), selected: visa);

    expect(find.text('Expired 09/26'), findsOneWidget);

    Finder fadeOf(String title) => find.ancestor(
          of: find.text(title),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container && widget.foregroundDecoration != null,
          ),
        );
    expect(fadeOf('Visa ending 1111'), findsOneWidget);
    expect(fadeOf('Visa ending 4242'), findsNothing);

    await tester.tap(find.text('Visa ending 1111'));
    expect(picked, isEmpty);
  });

  testWidgets('while cards load, a line shows and Card cannot be tapped',
      (tester) async {
    await show(tester, cards: const CardsState());

    expect(find.text('Loading your cards...'), findsOneWidget);
    expect(isTicked(tester, 'Cash'), isTrue);

    await tester.tap(find.text('Card'));
    expect(picked, isEmpty);
    expect(manageTaps, 0);
  });

  testWidgets('when cards fail, cash stays and Retry works', (tester) async {
    await show(
      tester,
      cards: const CardsState(
        status: CardsStatus.failure,
        errorMessage: 'No internet connection.',
      ),
    );

    expect(find.text('Cards could not load.'), findsOneWidget);
    expect(isTicked(tester, 'Cash'), isTrue);

    await tester.tap(find.text('Card'));
    expect(picked, isEmpty);

    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('Manage cards works', (tester) async {
    await show(tester, cards: loaded([visa]), selected: visa);

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
    await tester.tap(find.text('Cash'));
    await tester.tap(find.text('Card'));
    await tester.tap(find.text('Manage cards'));

    expect(picked, isEmpty);
    expect(manageTaps, 0);
  });

  testWidgets('a small phone shows everything with no overflow',
      (tester) async {
    await show(
      tester,
      cards: loaded([visa, failing, expired]),
      selected: visa,
      width: 960,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
  });
}