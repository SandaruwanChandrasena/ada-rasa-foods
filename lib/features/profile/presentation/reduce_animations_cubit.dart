import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/settings_repository.dart';

// The in-app "Reduce animations" switch. True means animations are off.
// The app also turns them off when the phone setting is on.
class ReduceAnimationsCubit extends Cubit<bool> {
  ReduceAnimationsCubit(this._repository)
      : super(_repository.reduceAnimations);

  final SettingsRepository _repository;

  Future<void> set(bool value) async {
    if (value == state) return;

    // The switch moves at once. If saving fails, it moves back.
    emit(value);
    try {
      await _repository.setReduceAnimations(value);
    } catch (_) {
      if (!isClosed) emit(!value);
    }
  }
}