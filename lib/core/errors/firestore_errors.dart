import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'data_failure.dart';

// Turns a Firebase error into a simple message for the user.
DataFailure toDataFailure(Object error) {
  if (error is DataFailure) return error;

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return const DataFailure('You do not have permission to see this.');
      case 'unavailable':
        return const DataFailure('No internet connection. Please try again.');
    }
  }
  return const DataFailure('Something went wrong. Please try again.');
}

extension DataFailureStream<T> on Stream<T> {
  // Every error in the stream becomes a DataFailure.
  Stream<T> mapErrorsToDataFailure() {
    return transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stackTrace, sink) {
          sink.addError(toDataFailure(error), stackTrace);
        },
      ),
    );
  }
}