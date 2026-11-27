import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/photo_confirm_sheet.dart';
import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:ada_rasa_foods/features/menu/domain/image_uploader.dart';
import 'package:ada_rasa_foods/features/menu/domain/menu_repository.dart';
import 'package:ada_rasa_foods/features/menu/domain/photo_picker.dart';
import 'package:ada_rasa_foods/features/menu/presentation/dish_form_cubit.dart';
import 'package:ada_rasa_foods/features/menu/presentation/dish_form_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockMenuRepository extends Mock implements MenuRepository {}

class MockImageUploader extends Mock implements ImageUploader {}

class MockPhotoPicker extends Mock implements PhotoPicker {}

const kottu = Dish(
  id: 'd1',
  restaurantId: 'r1',
  name: 'Chicken Kottu',
  price: 1200,
  category: 'Kottu',
  description: 'Spicy.',
);

const kottuWithPhoto = Dish(
  id: 'd2',
  restaurantId: 'r1',
  name: 'Egg Kottu',
  price: 900,
  category: 'Kottu',
  imageUrl: 'https://example.com/egg.jpg',
);

const pickedPath = '/cache/picked.jpg';
const newUrl = 'https://res.cloudinary.com/dtmcqgolr/new.jpg';

void main() {
  late MockMenuRepository repository;
  late MockImageUploader uploader;
  late MockPhotoPicker picker;

  setUpAll(() => registerFallbackValue(kottu));

  setUp(() {
    repository = MockMenuRepository();
    when(() => repository.addDish(any())).thenAnswer((_) async => 'new1');
    when(() => repository.updateDish(any())).thenAnswer((_) async {});
    when(() => repository.deleteDish(any())).thenAnswer((_) async {});

    uploader = MockImageUploader();
    when(
      () => uploader.upload(any(), onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) async => newUrl);

    picker = MockPhotoPicker();
    when(() => picker.pickFromGallery()).thenAnswer((_) async => pickedPath);
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
                      uploader: uploader,
                      picker: picker,
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

  Finder deleteButton() => find.byKey(const Key('delete-dish-button'));
  Finder photoBox() => find.byKey(const Key('dish-photo-box'));
  Finder changePhoto() => find.byKey(const Key('dish-change-photo'));
  Finder removePhoto() => find.byKey(const Key('dish-remove-photo'));

  Future<void> tapDelete(WidgetTester tester) async {
    await tester.ensureVisible(deleteButton());
    await tester.pumpAndSettle();
    await tester.tap(deleteButton());
    await tester.pumpAndSettle();
  }

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

  // Tap the empty photo box, then Use photo in the sheet.
  Future<void> choosePhoto(WidgetTester tester) async {
    await tester.tap(photoBox());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use photo'));
    await tester.pumpAndSettle();
  }

  // An upload that waits. Call report() to send progress.
  ({Completer<String> done, void Function(double) report}) slowUpload() {
    final done = Completer<String>();
    void Function(double)? onProgress;
    when(
      () => uploader.upload(any(), onProgress: any(named: 'onProgress')),
    ).thenAnswer((call) {
      onProgress = call.namedArguments[#onProgress] as void Function(double)?;
      return done.future;
    });
    return (done: done, report: (value) => onProgress?.call(value));
  }

  testWidgets('the add page is empty and has no Delete', (tester) async {
    await openForm(tester);

    expect(find.widgetWithText(AppBar, 'Add dish'), findsOneWidget);
    expect(saveButton('Add dish'), findsOneWidget);
    expect(deleteButton(), findsNothing);
    expect(textOf(tester, 'Dish name'), '');
  });

  testWidgets('the edit page is filled from the dish', (tester) async {
    await openForm(tester, dish: kottu);

    expect(find.widgetWithText(AppBar, 'Edit dish'), findsOneWidget);
    expect(saveButton('Save'), findsOneWidget);
    expect(deleteButton(), findsOneWidget);
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
    final chip = find.widgetWithText(CategoryChip, 'Drinks');
    await scrollTo(tester, chip);

    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(textOf(tester, 'Category'), 'Drinks');
  });

  testWidgets('the chip that matches the box is orange', (tester) async {
    await openForm(tester, dish: kottu);

    CategoryChip chip(String label) =>
        tester.widget<CategoryChip>(find.widgetWithText(CategoryChip, label));
    expect(chip('Kottu').selected, isTrue);
    expect(chip('Drinks').selected, isFalse);

    final kottuChip = find.widgetWithText(CategoryChip, 'Kottu');
    final material = tester.widget<Material>(
      find.descendant(of: kottuChip, matching: find.byType(Material)).first,
    );
    expect(material.color, AppTheme.brandOrange);

    await tester.enterText(field('Category'), 'Drinks');
    await tester.pumpAndSettle();

    expect(chip('Kottu').selected, isFalse);
    expect(chip('Drinks').selected, isTrue);
  });

  testWidgets('every text box has an orange icon', (tester) async {
    await openForm(tester);

    for (final icon in [
      Icons.restaurant_rounded,
      Icons.notes_rounded,
      Icons.sell_rounded,
      Icons.category_rounded,
    ]) {
      expect(tester.widget<Icon>(find.byIcon(icon)).color,
          AppTheme.brandOrange);
    }
  });

  testWidgets('the Available card switch turns the dish off',
      (tester) async {
    await openForm(tester);
    final toggle = find.byType(Switch);
    await scrollTo(tester, toggle);

    expect(find.text('Customers can order it.'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(toggle).value, isFalse);
    expect(find.text('Customers cannot order it.'), findsOneWidget);
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

    await tapDelete(tester);
    expect(find.text('Delete Chicken Kottu?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => repository.deleteDish(any()));
    expect(find.byType(DishFormView), findsOneWidget);
  });

  testWidgets('Delete asks, deletes, and closes', (tester) async {
    await openForm(tester, dish: kottu);

    await tapDelete(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => repository.deleteDish(kottu)).called(1);
    expect(find.byType(DishFormView), findsNothing);
    expect(find.text('Chicken Kottu is deleted.'), findsOneWidget);
  });

  testWidgets('Delete is a soft red button next to Save',
      (tester) async {
    await openForm(tester, dish: kottu);

    final button = tester.widget<TextButton>(deleteButton());
    final style = button.style!;
    expect(style.backgroundColor?.resolve({}), AppTheme.dangerBg);
    expect(style.foregroundColor?.resolve({}), AppTheme.dangerRed);
    expect(find.byIcon(Icons.delete_rounded), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Edit dish'), findsOneWidget);

    final deleteBox = tester.getRect(deleteButton());
    final saveBox = tester.getRect(saveButton('Save'));
    expect(deleteBox.center.dy, saveBox.center.dy);
    expect(deleteBox.left, lessThan(saveBox.left));
  });

  testWidgets('Delete is locked while saving', (tester) async {
    final done = Completer<void>();
    when(() => repository.updateDish(any())).thenAnswer((_) => done.future);
    await openForm(tester, dish: kottu);

    await tester.tap(saveButton('Save'));
    await tester.pump();

    expect(tester.widget<TextButton>(deleteButton()).onPressed, isNull);

    await tester.tap(deleteButton(), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Delete Chicken Kottu?'), findsNothing);
    verifyNever(() => repository.deleteDish(any()));

    done.complete();
    await tester.pumpAndSettle();
  });

  group('photo', () {
    testWidgets('a new dish shows Add a photo and no round buttons',
        (tester) async {
      await openForm(tester);

      expect(find.byType(DishPhotoBox), findsOneWidget);
      expect(find.text('Add a photo'), findsOneWidget);
      expect(changePhoto(), findsNothing);
      expect(removePhoto(), findsNothing);
      expect(find.byKey(const Key('picked-photo')), findsNothing);
    });

    testWidgets('a dish with a photo shows the camera and the bin',
        (tester) async {
      await openForm(tester, dish: kottuWithPhoto);

      expect(find.text('Add a photo'), findsNothing);
      expect(changePhoto(), findsOneWidget);
      expect(removePhoto(), findsOneWidget);
      final bin = tester.widget<Icon>(
        find.descendant(of: removePhoto(), matching: find.byType(Icon)),
      );
      expect(bin.color, AppTheme.dangerRed);
    });

    testWidgets('the camera button opens the gallery', (tester) async {
      await openForm(tester, dish: kottuWithPhoto);

      await tester.tap(changePhoto());
      await tester.pumpAndSettle();

      verify(() => picker.pickFromGallery()).called(1);
      expect(find.byType(PhotoConfirmSheet), findsOneWidget);
    });

    testWidgets('the photo shows the sheet first', (tester) async {
      await openForm(tester);

      await tester.tap(photoBox());
      await tester.pumpAndSettle();

      expect(find.byType(PhotoConfirmSheet), findsOneWidget);
      expect(find.text('Use this photo?'), findsOneWidget);
      expect(find.byKey(const Key('picked-photo')), findsNothing);
    });

    testWidgets('Cancel in the sheet adds no photo', (tester) async {
      await openForm(tester);

      await tester.tap(photoBox());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoConfirmSheet), findsNothing);
      expect(find.byKey(const Key('picked-photo')), findsNothing);
      expect(find.text('Add a photo'), findsOneWidget);
      expect(removePhoto(), findsNothing);
    });

    testWidgets('Use photo shows the preview and the round buttons',
        (tester) async {
      await openForm(tester);

      await choosePhoto(tester);

      expect(find.byKey(const Key('picked-photo')), findsOneWidget);
      expect(changePhoto(), findsOneWidget);
      expect(removePhoto(), findsOneWidget);
      verifyNever(
        () => uploader.upload(any(), onProgress: any(named: 'onProgress')),
      );
    });

    testWidgets('tapping the photo box opens the gallery too',
        (tester) async {
      await openForm(tester);

      await tester.tap(photoBox());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use photo'));
      await tester.pumpAndSettle();

      verify(() => picker.pickFromGallery()).called(1);
      expect(find.byKey(const Key('picked-photo')), findsOneWidget);
    });

    testWidgets('the bin takes the photo away, with no question',
        (tester) async {
      await openForm(tester, dish: kottuWithPhoto);

      await tester.tap(removePhoto());
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(removePhoto(), findsNothing);
      expect(find.text('Add a photo'), findsOneWidget);
    });

    testWidgets('a gallery error shows the reason', (tester) async {
      when(() => picker.pickFromGallery()).thenThrow(
        const DataFailure('Could not open your photos.'),
      );
      await openForm(tester);

      await tester.tap(photoBox());
      await tester.pumpAndSettle();

      expect(find.byType(PhotoConfirmSheet), findsNothing);
      expect(find.text('Could not open your photos.'), findsOneWidget);
      expect(find.byKey(const Key('picked-photo')), findsNothing);
    });

    testWidgets('uploading shows the progress and locks the form',
        (tester) async {
      final upload = slowUpload();
      await openForm(tester);
      await fillForm(tester);
      await choosePhoto(tester);

      await tester.tap(saveButton('Add dish'));
      await tester.pump();
      upload.report(0.45);
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Uploading 45%'), findsOneWidget);
      expect(tester.widget<TextField>(field('Dish name')).enabled, isFalse);
      expect(changePhoto(), findsNothing);
      expect(removePhoto(), findsNothing);
      final box = tester.widget<InkWell>(photoBox());
      expect(box.onTap, isNull);

      upload.done.complete(newUrl);
      await tester.pumpAndSettle();
    });

    testWidgets('Back is blocked while uploading', (tester) async {
      final upload = slowUpload();
      await openForm(tester);
      await fillForm(tester);
      await choosePhoto(tester);
      await tester.tap(saveButton('Add dish'));
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(DishFormView), findsOneWidget);
      expect(find.text('Please wait, saving the dish.'), findsOneWidget);

      upload.done.complete(newUrl);
      await tester.pumpAndSettle();

      expect(find.byType(DishFormView), findsNothing);
    });

    testWidgets('a failed upload keeps the page and the photo',
        (tester) async {
      when(
        () => uploader.upload(any(), onProgress: any(named: 'onProgress')),
      ).thenThrow(
        const DataFailure('The photo could not be uploaded. Please try again.'),
      );
      await openForm(tester);
      await fillForm(tester);
      await choosePhoto(tester);

      await tester.tap(saveButton('Add dish'));
      await tester.pumpAndSettle();

      expect(find.byType(DishFormView), findsOneWidget);
      expect(find.byKey(const Key('picked-photo')), findsOneWidget);
      expect(
        find.text('The photo could not be uploaded. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      verifyNever(() => repository.addDish(any()));
    });

    testWidgets('saving with a photo saves its link and closes',
        (tester) async {
      await openForm(tester);
      await fillForm(tester);
      await choosePhoto(tester);

      await tester.tap(saveButton('Add dish'));
      await tester.pumpAndSettle();

      final saved =
          verify(() => repository.addDish(captureAny())).captured.single
              as Dish;
      expect(saved.imageUrl, newUrl);
      expect(find.byType(DishFormView), findsNothing);
    });
  });
}