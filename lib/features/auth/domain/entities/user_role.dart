enum UserRole {
  customer,
  restaurant,
  admin,
  rider;

  // Unknown or missing role becomes customer (the safest role).
  static UserRole fromValue(String? value) {
    for (final role in UserRole.values) {
      if (role.name == value) return role;
    }
    return UserRole.customer;
  }
}