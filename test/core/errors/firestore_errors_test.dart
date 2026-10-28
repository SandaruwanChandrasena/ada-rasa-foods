import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/core/errors/firestore_errors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

FirebaseException firebaseError(String code) {
  return FirebaseException(plugin: 'cloud_firestore', code: code);
}

void main() {
  group('toDataFailure', () {
    test('permission-denied gives a permission message', () {
      expect(
        toDataFailure(firebaseError('permission-denied')),
        const DataFailure('You do not have permission to see this.'),
      );
    });

    test('unavailable gives a no internet message', () {
      expect(
        toDataFailure(firebaseError('unavailable')),
        const DataFailure('No internet connection. Please try again.'),
      );
    });

    test('other Firebase errors give a general message', () {
      expect(
        toDataFailure(firebaseError('internal')),
        const DataFailure('Something went wrong. Please try again.'),
      );
    });

    test('non-Firebase errors give a general message', () {
      expect(
        toDataFailure(Exception('boom')),
        const DataFailure('Something went wrong. Please try again.'),
      );
    });

    test('a DataFailure stays the same', () {
      const failure = DataFailure('Custom message');
      expect(toDataFailure(failure), failure);
    });
  });

  group('mapErrorsToDataFailure', () {
    test('turns a stream error into a DataFailure', () {
      final stream = Stream<int>.error(firebaseError('unavailable'));

      expect(
        stream.mapErrorsToDataFailure(),
        emitsError(
          const DataFailure('No internet connection. Please try again.'),
        ),
      );
    });

    test('keeps normal values', () {
      final stream = Stream<int>.fromIterable([1, 2, 3]);

      expect(stream.mapErrorsToDataFailure(), emitsInOrder([1, 2, 3]));
    });
  });
}