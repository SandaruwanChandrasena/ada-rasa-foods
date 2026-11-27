import 'package:equatable/equatable.dart';

class Restaurant extends Equatable {
  const Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.ownerId,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.imageUrl = '',
    this.phone = '',
    this.description = '',
    this.isOpen = true,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String cuisine;
  final String ownerId;
  final String address;

  // Map point for Stage 2. Plain numbers keep Firebase out of the domain layer.
  final double latitude;
  final double longitude;

  // Empty means the app shows the default image.
  final String imageUrl;

  // The owner sets these. Phone is digits only, like 0712345678.
  // Empty means none, so old shops without them still work.
  final String phone;
  final String description;

  // The owner sets isOpen (RES-4). The admin sets isActive (ADM-3).
  final bool isOpen;
  final bool isActive;

  final DateTime? createdAt;

  bool get hasImage => imageUrl.isNotEmpty;

  bool get hasPhone => phone.isNotEmpty;

  // Closed or turned-off restaurants take no orders.
  bool get canTakeOrders => isOpen && isActive;

  @override
  List<Object?> get props => [
        id,
        name,
        cuisine,
        ownerId,
        address,
        latitude,
        longitude,
        imageUrl,
        phone,
        description,
        isOpen,
        isActive,
        createdAt,
      ];
}