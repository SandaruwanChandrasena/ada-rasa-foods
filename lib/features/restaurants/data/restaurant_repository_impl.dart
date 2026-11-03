import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/data_failure.dart';
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

  @override
  Future<void> setOpen(String restaurantId, {required bool isOpen}) async {
    final ref = _restaurants.doc(restaurantId);

    try {
      // Fails fast with no internet, so the switch never shows a wrong state.
      final doc = await ref.get(const GetOptions(source: Source.server));
      if (!doc.exists) {
        throw const DataFailure('This restaurant was not found.');
      }

      await ref.update({'isOpen': isOpen});
    } catch (error) {
      throw toDataFailure(error);
    }
  }

  @override
  Future<void> setImageUrl(String restaurantId, String imageUrl) async {
    final ref = _restaurants.doc(restaurantId);

    try {
      final doc = await ref.get(const GetOptions(source: Source.server));
      if (!doc.exists) {
        throw const DataFailure('This restaurant was not found.');
      }

      // The rules let the owner change only isOpen and imageUrl.
      await ref.update({'imageUrl': imageUrl});
    } catch (error) {
      throw toDataFailure(error);
    }
  }
}