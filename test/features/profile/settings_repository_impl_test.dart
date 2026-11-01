import 'dart:io';

import 'package:ada_rasa_foods/features/profile/data/settings_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

void main() {
  // A real Hive box in a temp folder, so we test the real saving.
  late Directory folder;
  late Box<dynamic> box;

  SettingsRepositoryImpl repository() => SettingsRepositoryImpl(box);

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('ada_rasa_settings_test');
    Hive.init(folder.path);
    box = await Hive.openBox<dynamic>(SettingsRepositoryImpl.boxName);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (folder.existsSync()) await folder.delete(recursive: true);
  });

  test('reduce animations is off when nothing is saved', () {
    expect(repository().reduceAnimations, isFalse);
  });

  test('turning it on is remembered', () async {
    await repository().setReduceAnimations(true);

    expect(repository().reduceAnimations, isTrue);
  });

  test('turning it off again is remembered', () async {
    await repository().setReduceAnimations(true);
    await repository().setReduceAnimations(false);

    expect(repository().reduceAnimations, isFalse);
  });

  test('it is still there after the app restarts', () async {
    await repository().setReduceAnimations(true);

    // Close and open the box again, like closing and opening the app.
    await box.close();
    box = await Hive.openBox<dynamic>(SettingsRepositoryImpl.boxName);

    expect(repository().reduceAnimations, isTrue);
  });

  test('broken data counts as off', () async {
    await box.put(SettingsRepositoryImpl.reduceAnimationsKey, 'yes');

    expect(repository().reduceAnimations, isFalse);
  });
}