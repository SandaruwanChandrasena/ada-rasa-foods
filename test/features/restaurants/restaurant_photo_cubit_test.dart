import 'dart:async';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/menu/domain/image_uploader.dart';
import 'package:ada_rasa_foods/features/menu/domain/photo_picker.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant_repository.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/restaurant_photo_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRestaurantRepository extends Mock implements RestaurantRepository {}

class MockImageUploader extends Mock implements ImageUploader {}

class MockPhotoPicker extends Mock implements PhotoPicker {}

const pickedPath = '/cache/shop.jpg';
const newUrl = 'https://res.cloudinary.com/dtmcqgolr/shop.jpg';

void main() {
  late MockRestaurantRepository repository;
  late MockImageUploader uploader;
  late MockPhotoPicker picker;

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
    repository = MockRestaurantRepository();
    when(() => repository.setImageUrl(any(), any())).thenAnswer((_) async {});

    uploader = MockImageUploader();
    stubUpload();

    picker = MockPhotoPicker();
    when(() => picker.pickFromGallery()).thenAnswer((_) async => pickedPath);
  });

  RestaurantPhotoCubit makeCubit() => RestaurantPhotoCubit(
        repository,
        uploader: uploader,
        picker: picker,
        restaurantId: 'r1',
      );

  void verifyNoUpload() => verifyNever(
        () => uploader.upload(any(), onProgress: any(named: 'onProgress')),
      );

  test('starts idle with no photo and no message', () {
    final state = makeCubit().state;

    expect(state.status, RestaurantPhotoStatus.idle);
    expect(state.isBusy, isFalse);
    expect(state.photoPath, isNull);
    expect(state.notice, isNull);
  });

  group('pick and upload', () {
    test('uploads the picked photo and saves its link', () async {
      final cubit = makeCubit();

      await cubit.pickAndUpload();

      verify(
        () => uploader.upload(
          pickedPath,
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      verify(() => repository.setImageUrl('r1', newUrl)).called(1);
      expect(cubit.state.status, RestaurantPhotoStatus.idle);
      expect(cubit.state.photoPath, isNull);
      expect(cubit.state.notice, 'Restaurant photo is saved.');
      expect(cubit.state.noticeId, 1);
    });

    test('shows the photo and progress while uploading, then saving',
        () async {
      final cubit = makeCubit();
      final states = <RestaurantPhotoState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.pickAndUpload();
      // The stream sends states a little later, so let them all arrive.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      final uploading = states.where((s) => s.isUploading).toList();
      expect(uploading.map((s) => s.uploadProgress), [0, 0.5, 1]);
      expect(uploading.every((s) => s.photoPath == pickedPath), isTrue);
      final saving = states.indexWhere(
        (s) => s.status == RestaurantPhotoStatus.saving,
      );
      expect(saving, greaterThan(states.indexOf(uploading.last)));
    });

    test('closing the gallery changes nothing', () async {
      when(() => picker.pickFromGallery()).thenAnswer((_) async => null);
      final cubit = makeCubit();

      await cubit.pickAndUpload();

      expect(cubit.state, const RestaurantPhotoState());
      verifyNoUpload();
      verifyNever(() => repository.setImageUrl(any(), any()));
    });

    test('a gallery error shows the reason', () async {
      when(() => picker.pickFromGallery()).thenThrow(
        const DataFailure('Could not open your photos.'),
      );
      final cubit = makeCubit();

      await cubit.pickAndUpload();

      expect(cubit.state.notice, 'Could not open your photos.');
      expect(cubit.state.isBusy, isFalse);
      verifyNoUpload();
    });

    test('a failed upload saves nothing and shows the reason', () async {
      when(
        () => uploader.upload(any(), onProgress: any(named: 'onProgress')),
      ).thenThrow(
        const DataFailure('No internet connection. Please try again.'),
      );
      final cubit = makeCubit();

      await cubit.pickAndUpload();

      verifyNever(() => repository.setImageUrl(any(), any()));
      expect(cubit.state.status, RestaurantPhotoStatus.idle);
      expect(cubit.state.photoPath, isNull);
      expect(cubit.state.uploadProgress, 0);
      expect(
        cubit.state.notice,
        'No internet connection. Please try again.',
      );
    });

    test('a failed save after the upload shows the reason', () async {
      when(() => repository.setImageUrl(any(), any())).thenThrow(
        const DataFailure('This restaurant was not found.'),
      );
      final cubit = makeCubit();

      await cubit.pickAndUpload();

      expect(cubit.state.status, RestaurantPhotoStatus.idle);
      expect(cubit.state.photoPath, isNull);
      expect(cubit.state.notice, 'This restaurant was not found.');
    });

    test('a strange error shows a simple message', () async {
      when(() => repository.setImageUrl(any(), any()))
          .thenThrow(Exception('boom'));
      final cubit = makeCubit();

      await cubit.pickAndUpload();

      expect(
        cubit.state.notice,
        'Something went wrong. Please try again.',
      );
    });

    test('trying again after a failure works', () async {
      when(
        () => uploader.upload(any(), onProgress: any(named: 'onProgress')),
      ).thenThrow(const DataFailure('The photo could not be uploaded.'));
      final cubit = makeCubit();
      await cubit.pickAndUpload();

      stubUpload();
      await cubit.pickAndUpload();

      verify(() => repository.setImageUrl('r1', newUrl)).called(1);
      expect(cubit.state.notice, 'Restaurant photo is saved.');
      expect(cubit.state.noticeId, 2);
    });

    test('taps while uploading do nothing', () async {
      final done = Completer<String>();
      when(
        () => uploader.upload(any(), onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) => done.future);
      final cubit = makeCubit();

      final first = cubit.pickAndUpload();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.isUploading, isTrue);

      await cubit.pickAndUpload();
      await cubit.removePhoto();
      done.complete(newUrl);
      await first;

      verify(() => picker.pickFromGallery()).called(1);
      verify(() => repository.setImageUrl('r1', newUrl)).called(1);
      verifyNever(() => repository.setImageUrl('r1', ''));
    });
  });

  group('remove photo', () {
    test('saves an empty link and says so', () async {
      final cubit = makeCubit();

      await cubit.removePhoto();

      verify(() => repository.setImageUrl('r1', '')).called(1);
      verifyNoUpload();
      expect(cubit.state.status, RestaurantPhotoStatus.idle);
      expect(cubit.state.notice, 'Restaurant photo is removed.');
    });

    test('shows saving while it saves', () async {
      final done = Completer<void>();
      when(() => repository.setImageUrl(any(), any()))
          .thenAnswer((_) => done.future);
      final cubit = makeCubit();

      final remove = cubit.removePhoto();
      expect(cubit.state.status, RestaurantPhotoStatus.saving);
      expect(cubit.state.isBusy, isTrue);

      done.complete();
      await remove;
      expect(cubit.state.isBusy, isFalse);
    });

    test('a remove error shows the reason', () async {
      when(() => repository.setImageUrl(any(), any())).thenThrow(
        const DataFailure('No internet connection. Please try again.'),
      );
      final cubit = makeCubit();

      await cubit.removePhoto();

      expect(cubit.state.status, RestaurantPhotoStatus.idle);
      expect(
        cubit.state.notice,
        'No internet connection. Please try again.',
      );
    });
  });
}