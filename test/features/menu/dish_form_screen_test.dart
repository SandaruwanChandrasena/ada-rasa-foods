import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:ada_rasa_foods/features/menu/domain/menu_repository.dart';
import 'package:ada_rasa_foods/features/menu/presentation/dish_form_cubit.dart';
import 'package:ada_rasa_foods/features/menu/presentation/dish_form_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockMenuRepository extends Mock implements MenuRepository {}

const kottu = Dish(
  id: 'd1',
  restaurantId: 'r1',
  name: 'Chicken Kottu',
  price: 1200,
  category: 'Kottu',
  description: 'Spicy.',
);

void main() {
  late MockMenuRepository repository;

  setUpAll(() => registerFallbackValue(kottu));

  setUp(() {
    repository = MockMenuRepository();
    when(() => repository.addDish(any())).thenAnswer((_) async => 'new1');
    when(() => repository.updateDish(any())).thenAnswer((_) async {});
    when(() => repository.deleteDish(any())).thenAnswer((_) async {});
  });

  // A start page with an Open button, so we can see the form close.
  Future<void> openForm(WidgetTester tester, {Dish? dish}) async {
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
                    create: (_) => DishFormCubit(
                      repository,
                      restaurantId: 'r1',
                      dish: dish,
                    ),
                    child: const DishFormView(
                      categories: ['Drinks', 'Kottu'],
                    ),
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

  Finder saveButton(String text) => find.widgetWithText(FilledButton, text);

  // Text fields have their own Scrollable, so we name the page list.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(WidgetTester tester) async {
    await tester.enterText(field('Dish name'), 'Cheese Kottu');
    await tester.enterText(field('Price'), '1500');
    await tester.enterText(field('Category'), 'Kottu');
    await tester.pump();
  }

  testWidgets('the add page is empty and has no Delete', (tester) async {
    await openForm(tester);

    expect(find.widgetWithText(AppBar, 'Add dish'), findsOneWidget);
    expect(saveButton('Add dish'), findsOneWidget);
    expect(find.byTooltip('Delete dish'), findsNothing);
    expect(textOf(tester, 'Dish name'), '');
  });

  testWidgets('the edit page is filled from the dish', (tester) async {
    await openForm(tester, dish: kottu);

    expect(find.widgetWithText(AppBar, 'Edit dish'), findsOneWidget);
    expect(saveButton('Save changes'), findsOneWidget);
    expect(find.byTooltip('Delete dish'), findsOneWidget);
    expect(textOf(tester, 'Dish name'), 'Chicken Kottu');
    expect(textOf(tester, 'Price'), '1200');
    expect(textOf(tester, 'Category'), 'Kottu');
  });

  testWidgets('saving an empty form shows the errors', (tester) async {
    await openForm(tester);

    await tester.tap(saveButton('Add dish'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter the dish name.'), findsOneWidget);
    expect(find.text('Please enter the price.'), findsOneWidget);
    expect(find.text('Please enter a category.'), findsOneWidget);
    verifyNever(() => repository.addDish(any()));
  });

  testWidgets('the price field takes digits only', (tester) async {
    await openForm(tester);

    await tester.enterText(field('Price'), '12a.5');
    await tester.pump();

    expect(textOf(tester, 'Price'), '125');
  });

  testWidgets('a category chip fills the category', (tester) async {
    await openForm(tester);
    final chip = find.widgetWithText(ActionChip, 'Drinks');
    await scrollTo(tester, chip);

    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(textOf(tester, 'Category'), 'Drinks');
  });

  testWidgets('a filled form adds the dish and closes', (tester) async {
    await openForm(tester);
    await fillForm(tester);

    await tester.tap(saveButton('Add dish'));
    await tester.pumpAndSettle();

    final saved =
        verify(() => repository.addDish(captureAny())).captured.single as Dish;
    expect(saved.name, 'Cheese Kottu');
    expect(saved.price, 1500);
    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(DishFormView), findsNothing);
    expect(find.text('Cheese Kottu is added to the menu.'), findsOneWidget);
  });

  testWidgets('a save error keeps the page open', (tester) async {
    when(() => repository.addDish(any())).thenThrow(
      const DataFailure('No internet connection. Please try again.'),
    );
    await openForm(tester);
    await fillForm(tester);

    await tester.tap(saveButton('Add dish'));
    await tester.pumpAndSettle();

    expect(find.byType(DishFormView), findsOneWidget);
    expect(
      find.text('No internet connection. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('the button shows a spinner while saving', (tester) async {
    final done = Completer<String>();
    when(() => repository.addDish(any())).thenAnswer((_) => done.future);
    await openForm(tester);
    await fillForm(tester);

    await tester.tap(saveButton('Add dish'));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    done.complete('new1');
    await tester.pumpAndSettle();
  });

  testWidgets('Cancel keeps the dish', (tester) async {
    await openForm(tester, dish: kottu);

    await tester.tap(find.byTooltip('Delete dish'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Chicken Kottu?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => repository.deleteDish(any()));
    expect(find.byType(DishFormView), findsOneWidget);
  });

  testWidgets('Delete asks, deletes, and closes', (tester) async {
    await openForm(tester, dish: kottu);

    await tester.tap(find.byTooltip('Delete dish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => repository.deleteDish(kottu)).called(1);
    expect(find.byType(DishFormView), findsNothing);
    expect(find.text('Chicken Kottu is deleted.'), findsOneWidget);
  });
}