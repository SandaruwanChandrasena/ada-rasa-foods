import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:ada_rasa_foods/features/menu/domain/image_uploader.dart';
import 'package:ada_rasa_foods/features/menu/domain/menu_repository.dart';
import 'package:ada_rasa_foods/features/menu/domain/photo_picker.dart';
import 'package:ada_rasa_foods/features/menu/presentation/dish_form_cubit.dart';
import 'package:ada_rasa_foods/features/menu/presentation/dish_form_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMenuRepository extends Mock implements MenuRepository {}

class MockImageUploader extends Mock implements ImageUploader {}

class MockPhotoPicker extends Mock implements PhotoPicker {}

const pickedPath = '/cache/picked.jpg';
const newUrl = 'https://res.cloudinary.com/dtmcqgolr/new.jpg';

// The owner taps Use photo in the sheet.
Future<PhotoChoice> useIt(String path) async => PhotoChoice.use;

const kottu = Dish(
  id: 'd1',
  restaurantId: 'r1',
  name: 'Chicken Kottu',
  price: 1200,
  category: 'Kottu',
  description: 'Spicy.',
  imageUrl: 'https://example.com/kottu.jpg',
);

void main() {
  late MockMenuRepository repository;
  late MockImageUploader uploader;
  late MockPhotoPicker picker;

  setUpAll(() => registerFallbackValue(kottu));

  // The upload reports 0.5 and then 1, like a real upload.
  void stubUpload() {
    when(
      () => uploader.upload(any(), onProgress: any(named: 'onProgress')),
    ).thenAnswer((call) async {
      final onProgress =
          call.namedArguments[#onProgress] as void Function(double)?;
      onProgress?.call(0.5);
      onProgress?.call(1);
      return newUrl;
    });
  }

  setUp(() {
    repository = MockMenuRepository();
    when(() => repository.addDish(any())).thenAnswer((_) async => 'new1');
    when(() => repository.updateDish(any())).thenAnswer((_) async {});
    when(() => repository.deleteDish(any())).thenAnswer((_) async {});

    uploader = MockImageUploader();
    picker = MockPhotoPicker();
    when(() => picker.pickFromGallery()).thenAnswer((_) async => pickedPath);
    stubUpload();
  });

  void verifyNoUpload() => verifyNever(
        () => uploader.upload(any(), onProgress: any(named: 'onProgress')),
      );

  DishFormCubit addForm() => DishFormCubit(
        repository,
        uploader: uploader,
        picker: picker,
        restaurantId: 'r1',
      );

  DishFormCubit editForm() => DishFormCubit(
        repository,
        uploader: uploader,
        picker: picker,
        restaurantId: 'r1',
        dish: kottu,
      );

  Dish savedNewDish() =>
      verify(() => repository.addDish(captureAny())).captured.single as Dish;

  Dish savedEditedDish() =>
      verify(() => repository.updateDish(captureAny())).captured.single
          as Dish;

  void fill(
    DishFormCubit cubit, {
    String name = 'Cheese Kottu',
    String price = '1500',
    String category = 'Kottu',
  }) {
    cubit
      ..nameChanged(name)
      ..priceChanged(price)
      ..categoryChanged(category);
  }

  group('starting', () {
    test('a new form is empty, available, and shows no errors', () {
      final state = addForm().state;

      expect(state.isEditing, isFalse);
      expect(state.name, '');
      expect(state.available, isTrue);
      expect(state.showErrors, isFalse);
    });

    test('an edit form is filled from the dish', () {
      final state = editForm().state;

      expect(state.isEditing, isTrue);
      expect(state.name, 'Chicken Kottu');
      expect(state.price, '1200');
      expect(state.category, 'Kottu');
      expect(state.description, 'Spicy.');
    });
  });

  group('checks', () {
    test('an empty form has an error for name, price, and category', () {
      final state = addForm().state;

      expect(state.nameError, 'Please enter the dish name.');
      expect(state.priceError, 'Please enter the price.');
      expect(state.categoryError, 'Please enter a category.');
      expect(state.isValid, isFalse);
    });

    test('only spaces count as empty', () {
      final cubit = addForm();
      fill(cubit, name: '   ', category: '  ');

      expect(cubit.state.nameError, 'Please enter the dish name.');
      expect(cubit.state.categoryError, 'Please enter a category.');
    });

    test('a price of 0 is refused', () {
      final cubit = addForm();
      fill(cubit, price: '0');

      expect(cubit.state.priceError, 'The price must be at least 1.');
    });

    test('a price above the limit is refused', () {
      final cubit = addForm();
      fill(cubit, price: '100001');

      expect(cubit.state.priceError, 'The price is too high.');
    });

    test('a very long name is refused', () {
      final cubit = addForm();
      fill(cubit, name: 'a' * 61);

      expect(cubit.state.nameError, 'Use 60 letters or less.');
    });

    test('a filled form is valid', () {
      final cubit = addForm();
      fill(cubit);

      expect(cubit.state.isValid, isTrue);
    });
  });

  group('save', () {
    test('an empty form shows errors and saves nothing', () async {
      final cubit = addForm();

      await cubit.save();

      expect(cubit.state.showErrors, isTrue);
      expect(cubit.state.status, DishFormStatus.editing);
      verifyNever(() => repository.addDish(any()));
    });

    test('a new dish is added with spaces trimmed', () async {
      final cubit = addForm();
      fill(cubit, name: '  Cheese Kottu ', category: ' Kottu ');
      cubit
        ..descriptionChanged(' With cheese. ')
        ..availableChanged(false);

      await cubit.save();

      final saved = verify(() => repository.addDish(captureAny()))
          .captured
          .single as Dish;
      expect(saved.restaurantId, 'r1');
      expect(saved.name, 'Cheese Kottu');
      expect(saved.category, 'Kottu');
      expect(saved.description, 'With cheese.');
      expect(saved.price, 1500);
      expect(saved.available, isFalse);
      expect(saved.imageUrl, '');
      expect(cubit.state.status, DishFormStatus.saved);
      expect(cubit.state.notice, 'Cheese Kottu is added to the menu.');
    });

    test('an edited dish keeps its id and photo', () async {
      final cubit = editForm()..priceChanged('1300');

      await cubit.save();

      final saved = verify(() => repository.updateDish(captureAny()))
          .captured
          .single as Dish;
      expect(saved.id, 'd1');
      expect(saved.price, 1300);
      expect(saved.imageUrl, 'https://example.com/kottu.jpg');
      expect(cubit.state.notice, 'Chicken Kottu is saved.');
      verifyNever(() => repository.addDish(any()));
    });

    test('it shows saving while it saves, and a second tap does nothing',
        () async {
      final done = Completer<String>();
      when(() => repository.addDish(any())).thenAnswer((_) => done.future);
      final cubit = addForm();
      fill(cubit);

      final first = cubit.save();
      expect(cubit.state.status, DishFormStatus.saving);
      expect(cubit.state.isBusy, isTrue);

      await cubit.save();
      done.complete('new1');
      await first;

      verify(() => repository.addDish(any())).called(1);
      expect(cubit.state.status, DishFormStatus.saved);
    });

    test('a save error keeps the page open with the reason', () async {
      when(() => repository.addDish(any())).thenThrow(
        const DataFailure('No internet connection. Please try again.'),
      );
      final cubit = addForm();
      fill(cubit);

      await cubit.save();

      expect(cubit.state.status, DishFormStatus.editing);
      expect(
        cubit.state.notice,
        'No internet connection. Please try again.',
      );
      expect(cubit.state.noticeId, 1);
    });
  });

  group('delete', () {
    test('deletes the dish and says so', () async {
      final cubit = editForm();

      await cubit.delete();

      verify(() => repository.deleteDish(kottu)).called(1);
      expect(cubit.state.status, DishFormStatus.deleted);
      expect(cubit.state.notice, 'Chicken Kottu is deleted.');
    });

    test('does nothing on a new dish', () async {
      final cubit = addForm();

      await cubit.delete();

      verifyNever(() => repository.deleteDish(any()));
    });

    test('a delete error keeps the page open with the reason', () async {
      when(() => repository.deleteDish(any())).thenThrow(
        const DataFailure('This dish was not found.'),
      );
      final cubit = editForm();

      await cubit.delete();

      expect(cubit.state.status, DishFormStatus.editing);
      expect(cubit.state.notice, 'This dish was not found.');
    });
  });

  group('photo', () {
    test('picking a photo shows it, but does not upload', () async {
      final cubit = addForm();

      await cubit.pickPhoto(confirm: useIt);

      expect(cubit.state.photoPath, pickedPath);
      expect(cubit.state.needsUpload, isTrue);
      verifyNoUpload();
    });

    test('closing the gallery changes nothing', () async {
      when(() => picker.pickFromGallery()).thenAnswer((_) async => null);
      final cubit = editForm();
      final before = cubit.state;

      await cubit.pickPhoto(confirm: useIt);

      expect(cubit.state, before);
    });

    test('a gallery error shows the reason and no photo', () async {
      when(() => picker.pickFromGallery()).thenThrow(
        const DataFailure('Could not open your photos.'),
      );
      final cubit = addForm();

      await cubit.pickPhoto(confirm: useIt);

      expect(cubit.state.photoPath, isNull);
      expect(cubit.state.notice, 'Could not open your photos.');
      expect(cubit.state.noticeId, 1);
    });

    test('remove photo clears the saved and the picked photo', () async {
      final cubit = editForm();
      await cubit.pickPhoto(confirm: useIt);

      cubit.removePhoto();

      expect(cubit.state.hasPhoto, isFalse);
      expect(cubit.state.needsUpload, isFalse);
    });

    test('saving after remove saves an empty link', () async {
      final cubit = editForm()..removePhoto();

      await cubit.save();

      expect(savedEditedDish().imageUrl, '');
      verifyNoUpload();
    });
  });

  group('Use this photo sheet', () {
    test('the sheet gets the picked photo', () async {
      final shown = <String>[];
      final cubit = addForm();

      await cubit.pickPhoto(
        confirm: (path) async {
          shown.add(path);
          return PhotoChoice.use;
        },
      );

      expect(shown, [pickedPath]);
      expect(cubit.state.photoPath, pickedPath);
    });

    test('Cancel keeps the old photo and changes nothing', () async {
      final cubit = editForm();
      final before = cubit.state;

      await cubit.pickPhoto(confirm: (_) async => PhotoChoice.cancel);

      expect(cubit.state, before);
      expect(cubit.state.photoUrl, kottu.imageUrl);
    });

    test('Pick another opens the gallery again and uses the new photo',
        () async {
      final paths = ['/cache/first.jpg', '/cache/second.jpg'];
      when(() => picker.pickFromGallery())
          .thenAnswer((_) async => paths.removeAt(0));
      final choices = [PhotoChoice.pickAnother, PhotoChoice.use];
      final cubit = addForm();

      await cubit.pickPhoto(confirm: (_) async => choices.removeAt(0));

      verify(() => picker.pickFromGallery()).called(2);
      expect(cubit.state.photoPath, '/cache/second.jpg');
    });

    test('Pick another, then closing the gallery, adds no photo',
        () async {
      final paths = <String?>[pickedPath, null];
      when(() => picker.pickFromGallery())
          .thenAnswer((_) async => paths.removeAt(0));
      final cubit = addForm();

      await cubit.pickPhoto(confirm: (_) async => PhotoChoice.pickAnother);

      verify(() => picker.pickFromGallery()).called(2);
      expect(cubit.state.photoPath, isNull);
    });

    test('taps while the sheet is open do nothing', () async {
      final answer = Completer<PhotoChoice>();
      final cubit = editForm();

      final first = cubit.pickPhoto(confirm: (_) => answer.future);
      await Future<void>.delayed(Duration.zero);

      await cubit.pickPhoto(confirm: useIt);
      cubit.removePhoto();
      answer.complete(PhotoChoice.use);
      await first;

      verify(() => picker.pickFromGallery()).called(1);
      expect(cubit.state.photoPath, pickedPath);
      expect(cubit.state.photoUrl, kottu.imageUrl);
    });

    test('after Cancel, a new pick works', () async {
      final cubit = addForm();
      await cubit.pickPhoto(confirm: (_) async => PhotoChoice.cancel);

      await cubit.pickPhoto(confirm: useIt);

      expect(cubit.state.photoPath, pickedPath);
    });
  });

  group('save with a photo', () {
    test('a new dish uploads the photo, then saves its link', () async {
      final cubit = addForm();
      fill(cubit);
      await cubit.pickPhoto(confirm: useIt);

      await cubit.save();

      verify(
        () => uploader.upload(
          pickedPath,
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      expect(savedNewDish().imageUrl, newUrl);
      expect(cubit.state.status, DishFormStatus.saved);
      expect(cubit.state.photoPath, isNull);
    });

    test('it shows uploading with progress, then saving', () async {
      final cubit = addForm();
      fill(cubit);
      await cubit.pickPhoto(confirm: useIt);
      final states = <DishFormState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.save();
      // The stream sends states a little later, so let them all arrive.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      final uploading = states.where((s) => s.isUploading).toList();
      expect(
        uploading.map((s) => s.uploadProgress),
        [0, 0.5, 1],
      );
      final firstSaving = states.indexWhere(
        (s) => s.status == DishFormStatus.saving,
      );
      expect(firstSaving, greaterThan(states.indexOf(uploading.last)));
    });

    test('an edit with a new photo saves the new link', () async {
      final cubit = editForm();
      await cubit.pickPhoto(confirm: useIt);

      await cubit.save();

      expect(savedEditedDish().imageUrl, newUrl);
    });

    test('no new photo means no upload', () async {
      final cubit = editForm()..priceChanged('1300');

      await cubit.save();

      verifyNoUpload();
      expect(savedEditedDish().imageUrl, kottu.imageUrl);
    });

    test('a form with errors does not upload', () async {
      final cubit = addForm();
      await cubit.pickPhoto(confirm: useIt);

      await cubit.save();

      verifyNoUpload();
      expect(cubit.state.showErrors, isTrue);
      expect(cubit.state.photoPath, pickedPath);
    });

    test('a failed upload saves nothing and keeps the photo', () async {
      when(
        () => uploader.upload(any(), onProgress: any(named: 'onProgress')),
      ).thenThrow(
        const DataFailure('No internet connection. Please try again.'),
      );
      final cubit = addForm();
      fill(cubit);
      await cubit.pickPhoto(confirm: useIt);

      await cubit.save();

      verifyNever(() => repository.addDish(any()));
      expect(cubit.state.status, DishFormStatus.editing);
      expect(cubit.state.photoPath, pickedPath);
      expect(
        cubit.state.notice,
        'No internet connection. Please try again.',
      );
    });

    test('Save again after a failed upload uploads and saves', () async {
      when(
        () => uploader.upload(any(), onProgress: any(named: 'onProgress')),
      ).thenThrow(const DataFailure('The photo could not be uploaded.'));
      final cubit = addForm();
      fill(cubit);
      await cubit.pickPhoto(confirm: useIt);
      await cubit.save();

      stubUpload();
      await cubit.save();

      expect(savedNewDish().imageUrl, newUrl);
      expect(cubit.state.status, DishFormStatus.saved);
    });

    test('if the save fails after the upload, Save again does not upload',
        () async {
      when(() => repository.addDish(any())).thenThrow(
        const DataFailure('No internet connection. Please try again.'),
      );
      final cubit = addForm();
      fill(cubit);
      await cubit.pickPhoto(confirm: useIt);
      await cubit.save();
      expect(cubit.state.photoUrl, newUrl);

      when(() => repository.addDish(any())).thenAnswer((_) async => 'new1');
      await cubit.save();

      verify(
        () => uploader.upload(any(), onProgress: any(named: 'onProgress')),
      ).called(1);
      final saved = verify(() => repository.addDish(captureAny()))
          .captured
          .last as Dish;
      expect(saved.imageUrl, newUrl);
    });

    test('a second Save tap while uploading does nothing', () async {
      final done = Completer<String>();
      when(
        () => uploader.upload(any(), onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) => done.future);
      final cubit = addForm();
      fill(cubit);
      await cubit.pickPhoto(confirm: useIt);

      final first = cubit.save();
      expect(cubit.state.isUploading, isTrue);
      expect(cubit.state.isBusy, isTrue);

      await cubit.save();
      await cubit.pickPhoto(confirm: useIt);
      cubit.removePhoto();
      done.complete(newUrl);
      await first;

      verify(
        () => uploader.upload(any(), onProgress: any(named: 'onProgress')),
      ).called(1);
      verify(() => picker.pickFromGallery()).called(1);
      expect(savedNewDish().imageUrl, newUrl);
    });
  });
}