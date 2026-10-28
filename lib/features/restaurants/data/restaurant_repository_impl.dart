import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/firestore_errors.dart';
import '../domain/restaurant.dart';
import '../domain/restaurant_repository.dart';
import 'restaurant_model.dart';

class RestaurantRepositoryImpl implements RestaurantRepository {
  RestaurantRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _restaurants =>
      _firestore.collection('restaurants');

  @override
  Stream<List<Restaurant>> watchActiveRestaurants() {
    return _restaurants
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final restaurants = snapshot.docs
              .map((doc) => RestaurantModel.fromMap(doc.id, doc.data()))
              .toList();

          // Sorted on the phone, so Firestore needs no extra index.
          restaurants.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          return restaurants;
        })
        .mapErrorsToDataFailure();
  }

  @override
  Stream<Restaurant?> watchRestaurant(String restaurantId) {
    return _restaurants
        .doc(restaurantId)
        .snapshots()
        .map((doc) {
          final data = doc.data();
          if (!doc.exists || data == null) return null;
          return RestaurantModel.fromMap(doc.id, data);
        })
        .mapErrorsToDataFailure();
  }
}