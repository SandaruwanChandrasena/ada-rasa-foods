import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/restaurant.dart';

// Turns a restaurants/{id} document into a Restaurant.
class RestaurantModel {
  const RestaurantModel._();

  // Missing fields get safe defaults: closed and hidden.
  static Restaurant fromMap(String id, Map<String, dynamic> map) {
    final location = map['location'];
    final createdAt = map['createdAt'];

    return Restaurant(
      id: id,
      name: map['name'] as String? ?? '',
      cuisine: map['cuisine'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      address: map['address'] as String? ?? '',
      latitude: location is GeoPoint ? location.latitude : 0.0,
      longitude: location is GeoPoint ? location.longitude : 0.0,
      imageUrl: map['imageUrl'] as String? ?? '',
      isOpen: map['isOpen'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? false,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}