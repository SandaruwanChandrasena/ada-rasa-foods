import 'package:hive_ce/hive_ce.dart';

import '../domain/settings_repository.dart';

// Saves app settings in a Hive box, one key per setting.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._box);

  // The box is opened once when the app starts.
  static const String boxName = 'settings';
  static const String reduceAnimationsKey = 'reduceAnimations';

  final Box<dynamic> _box;

  // Missing or broken data means "off".
  @override
  bool get reduceAnimations => _box.get(reduceAnimationsKey) == true;

  @override
  Future<void> setReduceAnimations(bool value) {
    return _box.put(reduceAnimationsKey, value);
  }
}