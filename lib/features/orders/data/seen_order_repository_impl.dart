import 'package:hive_ce/hive_ce.dart';

import '../domain/seen_order_repository.dart';

// Saves seen order ids in a Hive box. The key is the user id.
class SeenOrderRepositoryImpl implements SeenOrderRepository {
  SeenOrderRepositoryImpl(this._box);

  // The box is opened once when the app starts.
  static const String boxName = 'seenOrders';

  // Only the newest ids are kept, so the box stays small.
  static const int maxSaved = 50;

  final Box<dynamic> _box;

  @override
  Future<Set<String>> loadSeen(String userId) async {
    return _load(userId).toSet();
  }

  @override
  Future<void> markSeen(String userId, String orderId) async {
    final ids = _load(userId);
    if (ids.contains(orderId)) return;

    ids.add(orderId);
    final newest = ids.length > maxSaved
        ? ids.sublist(ids.length - maxSaved)
        : ids;
    await _box.put(userId, newest);
  }

  // Oldest first. Broken data gives an empty list.
  List<String> _load(String userId) {
    final data = _box.get(userId);
    if (data is! List) return [];
    return [
      for (final id in data)
        if (id is String && id.isNotEmpty) id,
    ];
  }
}