import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/firestore_errors.dart';
import '../../domain/entities/dish.dart';
import '../../domain/repositories/menu_repository.dart';
import '../models/dish_model.dart';

class MenuRepositoryImpl implements MenuRepository {
  MenuRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Dish>> watchMenu(String restaurantId) {
    return _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('menuItems')
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
}