import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/food_order.dart';
import '../domain/order_item.dart';
import '../domain/order_status.dart';

// Turns an orders/{id} document into a FoodOrder, and back.
class OrderModel {
  const OrderModel._();

  // Fields for a new order. Firestore sets both times.
  static Map<String, dynamic> toNewMap(FoodOrder order) {
    return {
      'customerId': order.customerId,
      'customerName': order.customerName,
      'restaurantId': order.restaurantId,
      'restaurantName': order.restaurantName,
      'restaurantAddress': order.restaurantAddress,
      'items': [for (final item in order.items) _itemToMap(item)],
      'total': order.total,
      'fulfillment': order.fulfillment.name,
      'status': order.status.name,
      'paymentMethod': order.paymentMethod.name,
      'paymentStatus': order.paymentStatus.name,
      'cardBrand': order.cardBrand,
      'cardLast4': order.cardLast4,
      'placedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Missing fields get safe defaults.
  static FoodOrder fromMap(String id, Map<String, dynamic> map) {
    final items = map['items'];

    return FoodOrder(
      id: id,
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      restaurantId: map['restaurantId'] as String? ?? '',
      restaurantName: map['restaurantName'] as String? ?? '',
      restaurantAddress: map['restaurantAddress'] as String? ?? '',
      items: items is List
          ? [
              for (final item in items)
                if (item is Map) _itemFromMap(item),
            ]
          : const [],
      total: (map['total'] as num?)?.toInt() ?? 0,
      fulfillment: _byName(
        Fulfillment.values,
        map['fulfillment'],
        Fulfillment.pickup,
      ),
      status: _byName(OrderStatus.values, map['status'], OrderStatus.placed),
      paymentMethod: _byName(
        PaymentMethod.values,
        map['paymentMethod'],
        PaymentMethod.cash,
      ),
      paymentStatus: _byName(
        PaymentStatus.values,
        map['paymentStatus'],
        PaymentStatus.pending,
      ),
      cardBrand: map['cardBrand'] as String? ?? '',
      cardLast4: map['cardLast4'] as String? ?? '',
      placedAt: _toDate(map['placedAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }

  static Map<String, dynamic> _itemToMap(OrderItem item) {
    return {
      'dishId': item.dishId,
      'name': item.name,
      'price': item.price,
      'quantity': item.quantity,
      'imageUrl': item.imageUrl,
    };
  }

  static OrderItem _itemFromMap(Map<dynamic, dynamic> map) {
    return OrderItem(
      dishId: map['dishId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      imageUrl: map['imageUrl'] as String? ?? '',
    );
  }

  // Firestore saves enums by name, like "ready".
  static T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
    return values.asNameMap()[name] ?? fallback;
  }

  // Null while the server time is still on its way.
  static DateTime? _toDate(Object? value) {
    return value is Timestamp ? value.toDate() : null;
  }
}