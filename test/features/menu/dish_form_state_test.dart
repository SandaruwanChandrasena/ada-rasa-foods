import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:ada_rasa_foods/features/menu/presentation/dish_form_state.dart';
import 'package:flutter_test/flutter_test.dart';

const kottu = Dish(
  id: 'd1',
  restaurantId: 'r1',
  name: 'Chicken Kottu',
  price: 1200,
  category: 'Kottu',
  imageUrl: 'https://example.com/kottu.jpg',
);

const noPhotoDish = Dish(
  id: 'd2',
  restaurantId: 'r1',
  name: 'Plain Rice',
  price: 300,
  category: 'Rice',
);

const newUrl = 'https://res.cloudinary.com/dtmcqgolr/new.jpg';
const pickedPath = '/data/user/0/cache/picked.jpg';

// Like the cubit does when it starts editing a dish.
DishFormState editState(Dish dish) => DishFormState(
      original: dish,
      name: dish.name,
      description: dish.description,
      price: '${dish.price}',
      category: dish.category,
      available: dish.available,
    );

DishFormState filledAddState() => const DishFormState(
      name: 'Cheese Kottu',
      price: '1500',
      category: 'Kottu',
    );

void main() {
  group('photo when the page opens', () {
    test('a new dish has no photo', () {
      const state = DishFormState();

      expect(state.photoUrl, '');
      expect(state.hasPhoto, isFalse);
      expect(state.needsUpload, isFalse);
    });

    test('editing a dish shows its saved photo', () {
      final state = editState(kottu);

      expect(state.photoUrl, kottu.imageUrl);
      expect(state.hasPhoto, isTrue);
      expect(state.needsUpload, isFalse);
    });

    test('editing a dish with no photo shows no photo', () {
      final state = editState(noPhotoDish);

      expect(state.photoUrl, '');
      expect(state.hasPhoto, isFalse);
    });

    test('saving an edit with no photo change keeps the old link', () {
      final dish = editState(kottu).toDish('r1');

      expect(dish.imageUrl, kottu.imageUrl);
    });

    test('a new dish is saved with an empty link', () {
      final dish = filledAddState().toDish('r1');

      expect(dish.imageUrl, '');
    });
  });

  group('picking a photo', () {
    test('a picked photo needs an upload', () {
      final state = filledAddState().copyWith(photoPath: pickedPath);

      expect(state.photoPath, pickedPath);
      expect(state.needsUpload, isTrue);
      expect(state.hasPhoto, isTrue);
    });

    test('a picked photo does not change the online link yet', () {
      final state = editState(kottu).copyWith(photoPath: pickedPath);

      expect(state.photoUrl, kottu.imageUrl);
      expect(state.toDish('r1').imageUrl, kottu.imageUrl);
    });

    test('typing in a field keeps the picked photo', () {
      final state = filledAddState()
          .copyWith(photoPath: pickedPath)
          .copyWith(name: 'Egg Kottu');

      expect(state.photoPath, pickedPath);
    });

    test('picking again replaces the first photo', () {
      final state = filledAddState()
          .copyWith(photoPath: pickedPath)
          .copyWith(photoPath: '/other.jpg');

      expect(state.photoPath, '/other.jpg');
    });
  });

  group('removing a photo', () {
    test('remove clears the saved photo', () {
      final state = editState(kottu).copyWith(
        imageUrl: '',
        clearPhotoPath: true,
      );

      expect(state.photoUrl, '');
      expect(state.hasPhoto, isFalse);
      expect(state.toDish('r1').imageUrl, '');
    });

    test('remove also clears a picked photo', () {
      final state = editState(kottu)
          .copyWith(photoPath: pickedPath)
          .copyWith(imageUrl: '', clearPhotoPath: true);

      expect(state.photoPath, isNull);
      expect(state.needsUpload, isFalse);
      expect(state.hasPhoto, isFalse);
    });

    test('remove keeps the dish being edited', () {
      final state = editState(kottu).copyWith(
        imageUrl: '',
        clearPhotoPath: true,
      );

      expect(state.original, kottu);
      expect(state.isEditing, isTrue);
    });
  });

  group('after the upload', () {
    test('the new link is saved and no upload is left', () {
      final state = editState(kottu)
          .copyWith(photoPath: pickedPath)
          .copyWith(imageUrl: newUrl, clearPhotoPath: true);

      expect(state.needsUpload, isFalse);
      expect(state.photoUrl, newUrl);
      expect(state.toDish('r1').imageUrl, newUrl);
    });

    test('a new dish gets the uploaded link', () {
      final state = filledAddState()
          .copyWith(photoPath: pickedPath)
          .copyWith(imageUrl: newUrl, clearPhotoPath: true);

      expect(state.toDish('r1').imageUrl, newUrl);
    });
  });

  group('uploading status', () {
    test('uploading is busy', () {
      final state = filledAddState().copyWith(
        status: DishFormStatus.uploading,
      );

      expect(state.isUploading, isTrue);
      expect(state.isBusy, isTrue);
    });

    test('saving and deleting are busy, but not uploading', () {
      final saving = filledAddState().copyWith(status: DishFormStatus.saving);
      final deleting = editState(kottu).copyWith(
        status: DishFormStatus.deleting,
      );

      expect(saving.isBusy, isTrue);
      expect(saving.isUploading, isFalse);
      expect(deleting.isBusy, isTrue);
      expect(deleting.isUploading, isFalse);
    });

    test('editing, saved and deleted are not busy', () {
      for (final status in [
        DishFormStatus.editing,
        DishFormStatus.saved,
        DishFormStatus.deleted,
      ]) {
        final state = filledAddState().copyWith(status: status);
        expect(state.isBusy, isFalse, reason: '$status');
      }
    });

    test('progress starts at 0 and is copied', () {
      final state = filledAddState().copyWith(uploadProgress: 0.45);

      expect(const DishFormState().uploadProgress, 0);
      expect(state.uploadProgress, 0.45);
    });

    test('a new progress makes a new state', () {
      final first = filledAddState().copyWith(uploadProgress: 0.2);
      final second = first.copyWith(uploadProgress: 0.6);

      expect(first == second, isFalse);
    });
  });
}