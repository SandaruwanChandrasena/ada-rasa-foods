import 'dart:async';

import 'package:ada_rasa_foods/features/payments/domain/card_brand.dart';
import 'package:ada_rasa_foods/features/payments/domain/card_repository.dart';
import 'package:ada_rasa_foods/features/payments/domain/payment_card.dart';
import 'package:ada_rasa_foods/features/payments/presentation/cards_cubit.dart';
import 'package:ada_rasa_foods/features/payments/presentation/my_cards_screen.dart';
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

  // Opens the 3-dot menu of the card at [index].
  Future<void> openMenu(WidgetTester tester, int index) async {
    await tester.tap(find.byTooltip('Card options').at(index));
    await tester.pumpAndSettle();
  }

  testWidgets('no cards shows a message and the Add card button',
      (tester) async {
    await showWith(tester, []);

    expect(find.text('You have no saved cards yet.'), findsOneWidget);
    expect(find.text('Add card'), findsOneWidget);
  });

  testWidgets('shows each card, its expiry, and the Default label',
      (tester) async {
    await showWith(tester, [visa, master]);

    expect(find.text('Visa ending 4242'), findsOneWidget);
    expect(find.text('Mastercard ending 4444'), findsOneWidget);
    expect(find.text('Expires 08/30'), findsNWidgets(2));
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('VISA'), findsOneWidget);
  });

  testWidgets('a card ending in 0002 shows Always fails (demo)',
      (tester) async {
    await showWith(tester, [visa, saved('c3', '0002')]);

    expect(find.text('Always fails (demo)'), findsOneWidget);
  });

  testWidgets('an expired card says Expired', (tester) async {
    await showWith(tester, [saved('c1', '1111', expMonth: 9, expYear: 2020)]);

    expect(find.text('Expired 09/20'), findsOneWidget);
  });

  testWidgets('the default card has no Set as default choice',
      (tester) async {
    await showWith(tester, [visa, master]);

    await openMenu(tester, 0);

    expect(find.text('Set as default'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('Set as default makes the other card default', (tester) async {
    await showWith(tester, [visa, master]);

    await openMenu(tester, 1);
    await tester.tap(find.text('Set as default'));
    await tester.pumpAndSettle();

    verify(() => repository.setDefault('u1', 'c2')).called(1);
    expect(
      find.text('Mastercard ending 4444 is now your default card.'),
      findsOneWidget,
    );
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