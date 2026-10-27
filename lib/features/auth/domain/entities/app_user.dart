import 'package:equatable/equatable.dart';

import 'user_role.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.restaurantId,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;

  // Only set for restaurant owners.
  final String? restaurantId;

  @override
  List<Object?> get props => [uid, name, email, phone, role, restaurantId];
}