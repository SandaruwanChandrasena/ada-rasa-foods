import 'dart:io';

import 'package:ada_rasa_foods/features/orders/data/seen_order_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

void main() {
  // A real Hive box in a temp folder, so we test the real saving.
  late Directory folder;
  late Box<dynamic> box;

  SeenOrderRepositoryImpl repository() => SeenOrderRepositoryImpl(box);

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('ada_rasa_seen_test');
    Hive.init(folder.path);
    box = await Hive.openBox<dynamic>(SeenOrderRepositoryImpl.boxName);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (folder.existsSync()) await folder.delete(recursive: true);
  });

  test('nothing saved gives an empty set', () async {
    expect(await repository().loadSeen('u1'), isEmpty);
  });

  test('a seen order is remembered', () async {
    await repository().markSeen('u1', 'o1');

    expect(await repository().loadSeen('u1'), {'o1'});
  });

  test('seen orders are still there after the app restarts', () async {
    await repository().markSeen('u1', 'o1');
    await repository().markSeen('u1', 'o2');

    // Close and open the box again, like closing and opening the app.
    await box.close();
    box = await Hive.openBox<dynamic>(SeenOrderRepositoryImpl.boxName);

    expect(await repository().loadSeen('u1'), {'o1', 'o2'});
  });

  test('each user has their own seen orders', () async {
    await repository().markSeen('u1', 'o1');

    expect(await repository().loadSeen('u2'), isEmpty);
    expect(await repository().loadSeen('u1'), {'o1'});
  });

  test('marking the same order twice saves it once', () async {
    await repository().markSeen('u1', 'o1');
    await repository().markSeen('u1', 'o1');

    expect(box.get('u1'), ['o1']);
  });

  test('keeps only the newest 50, and drops the oldest', () async {
    for (var i = 1; i <= 52; i++) {
      await repository().markSeen('u1', 'o$i');
    }

    final seen = await repository().loadSeen('u1');
    expect(seen, hasLength(SeenOrderRepositoryImpl.maxSaved));
    expect(seen, isNot(contains('o1')));
    expect(seen, isNot(contains('o2')));
    expect(seen, contains('o3'));
    expect(seen, contains('o52'));
  });

  test('broken saved data gives an empty set', () async {
    await box.put('u1', 'not a list');

    expect(await repository().loadSeen('u1'), isEmpty);
  });
}