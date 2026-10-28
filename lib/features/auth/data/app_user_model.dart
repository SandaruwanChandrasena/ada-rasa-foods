import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/app_user.dart';
import '../domain/user_role.dart';

class AppUserModel {
  const AppUserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.restaurantId,
  });

  // Missing fields get safe defaults, so the app does not crash.
  factory AppUserModel.fromMap(String uid, Map<String, dynamic> map) {
    return AppUserModel(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      role: UserRole.fromValue(map['role'] as String?),
      restaurantId: map['restaurantId'] as String?,
    );
  }

  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? restaurantId;

  // A new user is always a customer. The Firestore rules check this too.
  static Map<String, dynamic> newCustomerMap({
    required String name,
    required String email,
  }) {
    return {
      'name': name,
      'email': email,
      'phone': '',
      'role': UserRole.customer.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  AppUser toEntity() {
    return AppUser(
      uid: uid,
      name: name,
      email: email,
      phone: phone,
      role: role,
      restaurantId: restaurantId,
    );
  }
}