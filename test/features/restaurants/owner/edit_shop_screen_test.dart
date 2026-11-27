import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant_repository.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/owner/edit_shop_cubit.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/owner/edit_shop_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockRestaurantRepository extends Mock implements RestaurantRepository {}

const kottu = Restaurant(
  id: 'r1',
  name: 'Kottu Corner',
  cuisine: 'Sri Lankan',
  ownerId: 'o1',
  address: '112 Galle Road, Colombo 04',
  latitude: 6.9,
  longitude: 79.8,
  phone: '0712345678',
  description: 'Best kottu in town.',
);

void main() {
  late MockRestaurantRepository repository;

  setUp(() {
    repository = MockRestaurantRepository();
    when(
      () => repository.updateDetails(
        any(),
        name: any(named: 'name'),
        cuisine: any(named: 'cuisine'),
        phone: any(named: 'phone'),
        description: any(named: 'description'),
      ),
    ).thenAnswer((_) async {});
  });

  void answerSave(Future<void> Function() answer) {
    when(
      () => repository.updateDetails(
        any(),
        name: any(named: 'name'),
        cuisine: any(named: 'cuisine'),
        phone: any(named: 'phone'),
        description: any(named: 'description'),
      ),
    ).thenAnswer((_) => answer());
  }

  void verifyNoSave() {
    verifyNever(
      () => repository.updateDetails(
        any(),
        name: any(named: 'name'),
        cuisine: any(named: 'cuisine'),
        phone: any(named: 'phone'),
        description: any(named: 'description'),
      ),
    );
  }

  // A start page with an Open button, so we can see the page close.
  Future<void> openPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider(
                    create: (_) => EditShopCubit(repository, kottu),
                    child: const EditShopView(),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  String textOf(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
  }

  testWidgets('the page is filled from the shop', (tester) async {
    await openPage(tester);

    expect(find.widgetWithText(AppBar, 'Edit shop'), findsOneWidget);
    expect(textOf(tester, 'Shop name'), 'Kottu Corner');
    expect(textOf(tester, 'Cuisine'), 'Sri Lankan');
    expect(textOf(tester, 'Phone (optional)'), '071 234 5678');
    expect(textOf(tester, 'Description (optional)'), 'Best kottu in town.');
  });

  testWidgets('the address is grey and locked', (tester) async {
    await openPage(tester);

    final address = tester.widget<TextField>(field('Address'));
    expect(address.enabled, isFalse);
    expect(address.controller!.text, '112 Galle Road, Colombo 04');
    expect(find.text('Ask the admin to change the address.'), findsOneWidget);
    final pin = tester.widget<Icon>(find.byIcon(Icons.location_on_rounded));
    expect(pin.color, AppTheme.textMuted);
  });

  testWidgets('the 4 boxes have orange icons', (tester) async {
    await openPage(tester);

    for (final icon in [
      Icons.storefront_rounded,
      Icons.restaurant_rounded,
      Icons.phone_rounded,
      Icons.notes_rounded,
    ]) {
      expect(
        tester.widget<Icon>(find.byIcon(icon)).color,
        AppTheme.brandOrange,
      );
    }
  });

  testWidgets('the phone box takes only numbers, spaces and dashes',
      (tester) async {
    await openPage(tester);

    await tester.enterText(field('Phone (optional)'), '07a1-2 3');
    await tester.pump();

    expect(textOf(tester, 'Phone (optional)'), '071-2 3');
  });

  testWidgets('the description stops at 150 letters', (tester) async {
    await openPage(tester);

    await tester.enterText(field('Description (optional)'), 'd' * 160);
    await tester.pump();

    expect(textOf(tester, 'Description (optional)').length, 150);
  });

  testWidgets('an empty name shows an error and saves nothing',
      (tester) async {
    await openPage(tester);
    await tester.enterText(field('Shop name'), '');

    await tapSave(tester);

    expect(find.text('Please enter the shop name.'), findsOneWidget);
    expect(find.byType(EditShopView), findsOneWidget);
    verifyNoSave();
  });

  testWidgets('a wrong phone shows an error', (tester) async {
    await openPage(tester);
    await tester.enterText(field('Phone (optional)'), '0112345678');

    await tapSave(tester);

    expect(find.text('A mobile number starts with 07.'), findsOneWidget);
    verifyNoSave();
  });

  testWidgets('Save writes the changes and closes with a message',
      (tester) async {
    await openPage(tester);
    await tester.enterText(field('Shop name'), 'Kottu Corner Plus');
    await tester.enterText(field('Phone (optional)'), '077 111 2222');

    await tapSave(tester);

    verify(
      () => repository.updateDetails(
        'r1',
        name: 'Kottu Corner Plus',
        cuisine: 'Sri Lankan',
        phone: '0771112222',
        description: 'Best kottu in town.',
      ),
    ).called(1);
    expect(find.byType(EditShopView), findsNothing);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Shop details are saved.'), findsOneWidget);
  });

  testWidgets('Save with no changes just closes', (tester) async {
    await openPage(tester);

    await tapSave(tester);

    verifyNoSave();
    expect(find.byType(EditShopView), findsNothing);
    expect(find.text('Shop details are saved.'), findsNothing);
  });

  testWidgets('a save error keeps the page and shows the reason',
      (tester) async {
    answerSave(
      () async =>
          throw const DataFailure('No internet connection. Please try again.'),
    );
    await openPage(tester);
    await tester.enterText(field('Shop name'), 'New Name');

    await tapSave(tester);

    expect(find.byType(EditShopView), findsOneWidget);
    expect(
      find.text('No internet connection. Please try again.'),
      findsOneWidget,
    );
    expect(textOf(tester, 'Shop name'), 'New Name');
  });

  testWidgets('a spinner shows, and Back waits, while saving',
      (tester) async {
    final done = Completer<void>();
    answerSave(() => done.future);
    await openPage(tester);
    await tester.enterText(field('Shop name'), 'New Name');

    await tester.tap(saveButton());
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(field('Shop name')).enabled, isFalse);

    await tester.pageBack();
    await tester.pump();
    expect(find.byType(EditShopView), findsOneWidget);

    done.complete();
    await tester.pumpAndSettle();

    expect(find.byType(EditShopView), findsNothing);
  });
}