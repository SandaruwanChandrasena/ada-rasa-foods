import 'dart:async';

import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/features/payments/domain/card_brand.dart';
import 'package:ada_rasa_foods/features/payments/domain/card_repository.dart';
import 'package:ada_rasa_foods/features/payments/domain/payment_card.dart';
import 'package:ada_rasa_foods/features/payments/presentation/cards/cards_cubit.dart';
import 'package:ada_rasa_foods/features/payments/presentation/cards/mini_card.dart';
import 'package:ada_rasa_foods/features/payments/presentation/cards/my_cards_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockCardRepository extends Mock implements CardRepository {}

PaymentCard saved(
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

void main() {
  late MockCardRepository repository;
  late StreamController<List<PaymentCard>> cards;
  late CardsCubit cubit;

  final visa = saved('c1', '4242', isDefault: true);
  final master = saved('c2', '4444', brand: CardBrand.mastercard);

  setUpAll(() => registerFallbackValue(saved('x', '0000')));

  setUp(() {
    repository = MockCardRepository();
    cards = StreamController<List<PaymentCard>>.broadcast();
    when(() => repository.watchCards('u1'))
        .thenAnswer((_) => cards.stream);
    when(() => repository.deleteCard(any(), any()))
        .thenAnswer((_) async {});
    when(() => repository.setDefault(any(), any()))
        .thenAnswer((_) async {});
  });

  tearDown(() async {
    await cubit.close();
    await cards.close();
  });

  Future<void> showWith(WidgetTester tester, List<PaymentCard> list) async {
    // Made inside the test, so the test clock delivers the stream events.
    cubit = CardsCubit(repository)..start('u1');

    await tester.pumpWidget(
      BlocProvider<CardsCubit>.value(
        value: cubit,
        child: const MaterialApp(home: MyCardsView()),
      ),
    );
    cards.add(list);
    await tester.pumpAndSettle();
  }

  Finder rowOf(String id) => find.byKey(ValueKey('card_$id'));

  // Opens the 3-dot menu of the card at [index].
  Future<void> openMenu(WidgetTester tester, int index) async {
    await tester.tap(find.byTooltip('Card options').at(index));
    await tester.pumpAndSettle();
  }

  testWidgets('no cards shows a message and the Add card button',
      (tester) async {
    await showWith(tester, []);

    expect(find.text('No saved cards yet'), findsOneWidget);
    expect(find.text('Add a demo card to pay at checkout.'), findsOneWidget);
    expect(find.byIcon(Icons.credit_card_rounded), findsOneWidget);
    expect(find.text('Add card'), findsOneWidget);
  });

  testWidgets('each card has a mini picture, brand, last 4 and expiry',
      (tester) async {
    await showWith(tester, [visa, master]);

    expect(find.byType(MiniCard), findsNWidgets(2));
    expect(find.text('Visa'), findsOneWidget);
    expect(find.text('Mastercard'), findsOneWidget);
    expect(find.text('Ending in 4242'), findsOneWidget);
    expect(find.text('Ending in 4444'), findsOneWidget);
    expect(find.text('Expires 08/30'), findsNWidgets(2));
    expect(find.text('VISA'), findsOneWidget);
  });

  testWidgets('the default card has the Default pill and no orange border',
      (tester) async {
    await showWith(tester, [visa, master]);

    expect(
      find.descendant(of: rowOf('c1'), matching: find.text('Default')),
      findsOneWidget,
    );
    final box = tester.widget<Container>(
      find.descendant(of: rowOf('c1'), matching: find.byType(Container)).first,
    );
    final border = (box.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, AppTheme.border);
  });

  testWidgets('only the other card has a Set as default button',
      (tester) async {
    await showWith(tester, [visa, master]);

    expect(find.text('Set as default'), findsOneWidget);
    expect(
      find.descendant(of: rowOf('c2'), matching: find.text('Set as default')),
      findsOneWidget,
    );
  });

  testWidgets('Set as default on the row makes it default', (tester) async {
    await showWith(tester, [visa, master]);

    await tester.tap(find.text('Set as default'));
    await tester.pumpAndSettle();

    verify(() => repository.setDefault('u1', 'c2')).called(1);
    expect(
      find.text('Mastercard ending 4444 is now your default card.'),
      findsOneWidget,
    );
  });

  testWidgets('the 3-dot menu has only Delete', (tester) async {
    await showWith(tester, [visa, master]);

    await openMenu(tester, 1);

    expect(find.text('Delete'), findsOneWidget);
    // Only the row button, not a menu item.
    expect(find.text('Set as default'), findsOneWidget);
  });

  testWidgets('a card ending in 0002 shows Always fails (demo)',
      (tester) async {
    await showWith(tester, [visa, saved('c3', '0002')]);

    expect(find.text('Always fails (demo)'), findsOneWidget);
  });

  testWidgets('an expired card is faded, red, and has no Set as default',
      (tester) async {
    await showWith(tester, [
      visa,
      saved('c5', '1111', expMonth: 9, expYear: 2020),
    ]);

    expect(find.text('Expired 09/20'), findsOneWidget);
    final expiry = tester.widget<Text>(find.text('Expired 09/20'));
    expect(expiry.style?.color, AppTheme.dangerRed);
    expect(
      find.descendant(
        of: rowOf('c5'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container && widget.foregroundDecoration != null,
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Set as default'), findsNothing);
  });

  testWidgets('the green safe note shows under the cards', (tester) async {
    await showWith(tester, [visa, master]);

    final note = find.text(
      'Your card information is safe. Only the last 4 digits are saved.',
    );
    expect(note, findsOneWidget);
    expect(
      tester.getTopLeft(note).dy,
      greaterThan(tester.getTopLeft(rowOf('c2')).dy),
    );
  });

  testWidgets('a small phone has no overflow', (tester) async {
    tester.view.physicalSize = const Size(960, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await showWith(tester, [
      visa,
      saved('c3', '0002', brand: CardBrand.mastercard),
    ]);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Delete asks first, and Cancel keeps the card',
      (tester) async {
    await showWith(tester, [visa, master]);

    await openMenu(tester, 1);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Mastercard ending 4444?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => repository.deleteCard(any(), any()));
  });

  testWidgets('Delete and confirm deletes the card', (tester) async {
    await showWith(tester, [visa, master]);

    await openMenu(tester, 1);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => repository.deleteCard('u1', master)).called(1);
    expect(find.text('Mastercard ending 4444 deleted.'), findsOneWidget);
  });

  testWidgets('with 5 cards, Add card is off and a note shows',
      (tester) async {
    await showWith(tester, [
      for (var i = 1; i <= 5; i++) saved('c$i', '000$i', isDefault: i == 1),
    ]);

    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Add card'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text('You can save up to 5 cards. Delete one to add another.'),
      findsOneWidget,
    );
  });
}