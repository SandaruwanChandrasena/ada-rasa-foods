import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/data_failure.dart';
import '../../../core/errors/firestore_errors.dart';
import '../domain/dish.dart';
import '../domain/menu_repository.dart';
import 'dish_model.dart';

class MenuRepositoryImpl implements MenuRepository {
  MenuRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  // Reads from the server, so a save fails fast with no internet.
  static const GetOptions _server = GetOptions(source: Source.server);

  CollectionReference<Map<String, dynamic>> _items(String restaurantId) {
    return _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('menuItems');
  }

  @override
  Stream<List<Dish>> watchMenu(String restaurantId) {
    return _items(restaurantId)
        .snapshots()
        .map((snapshot) {
          final dishes = snapshot.docs
              .map((doc) => DishModel.fromMap(doc.id, restaurantId, doc.data()))
              .toList();

          // Group by category, then A to Z inside each category.
          dishes.sort((a, b) {
            final byCategory = a.category.compareTo(b.category);
            if (byCategory != 0) return byCategory;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
          return dishes;
        })
        .mapErrorsToDataFailure();
  }

  @override
  Future<String> addDish(Dish dish) async {
    try {
      final restaurant = await _firestore
          .collection('restaurants')
          .doc(dish.restaurantId)
          .get(_server);
      if (!restaurant.exists) {
        throw const DataFailure('This restaurant was not found.');
      }

      final doc = await _items(dish.restaurantId).add(DishModel.toMap(dish));
      return doc.id;
    } catch (error) {
      throw toDataFailure(error);
    }
  }

  @override
  Future<void> updateDish(Dish dish) async {
    try {
      final ref = await _existingDish(dish);
      await ref.set(DishModel.toMap(dish));
    } catch (error) {
      throw toDataFailure(error);
    }
  }

  @override
  Future<void> deleteDish(Dish dish) async {
    try {
      final ref = await _existingDish(dish);
      await ref.delete();
    } catch (error) {
      throw toDataFailure(error);
    }
  }

  @override
  Future<void> setAvailable(Dish dish, {required bool available}) async {
    try {
      final ref = await _existingDish(dish);
      await ref.update({'available': available});
    } catch (error) {
      throw toDataFailure(error);
    }
  }

  // Checks the dish is still there, from the server.
  Future<DocumentReference<Map<String, dynamic>>> _existingDish(
    Dish dish,
  ) async {
    final ref = _items(dish.restaurantId).doc(dish.id);
    final doc = await ref.get(_server);
    if (!doc.exists) {
      throw const DataFailure('This dish was not found.');
    }
    return ref;
  }
}