import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/data_failure.dart';
import '../../../core/errors/firestore_errors.dart';
import '../domain/food_order.dart';
import '../domain/order_repository.dart';
import '../domain/order_status.dart';
import 'order_model.dart';

class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  // My orders shows only the newest orders, so it loads fast.
  static const int maxCustomerOrders = 50;

  // The Done tab shows only the newest ended orders.
  static const int maxDoneOrders = 50;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  @override
  Future<String> placeOrder(FoodOrder order) async {
    try {
      // Fails fast with no internet, so the order is never left waiting.
      await _firestore
          .collection('restaurants')
          .doc(order.restaurantId)
          .get(const GetOptions(source: Source.server));

      final doc = await _orders.add(OrderModel.toNewMap(order));
      return doc.id;
    } catch (error) {
      throw toDataFailure(error);
    }
  }

  @override
  Stream<FoodOrder?> watchOrder(String orderId) {
    return _orders
        .doc(orderId)
        .snapshots()
        .map((doc) {
          final data = doc.data();
          if (!doc.exists || data == null) return null;
          return OrderModel.fromMap(doc.id, data);
        })
        .mapErrorsToDataFailure();
  }

  @override
  Stream<List<FoodOrder>> watchCustomerOrders(String customerId) {
    // Needs a Firestore index: customerId, then placedAt newest first.
    return _orders
        .where('customerId', isEqualTo: customerId)
        .orderBy('placedAt', descending: true)
        .limit(maxCustomerOrders)
        .snapshots()
        .map(_toOrders)
        .mapErrorsToDataFailure();
  }

  @override
  Future<void> cancelOrder(FoodOrder order) async {
    final ref = _orders.doc(order.id);

    try {
      // A transaction reads the latest status first.
      // So we never cancel an order the restaurant just accepted.
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(ref);
        final data = doc.data();
        if (!doc.exists || data == null) {
          throw const DataFailure('This order was not found.');
        }

        final latest = OrderModel.fromMap(doc.id, data);
        if (!latest.canCancel) {
          throw DataFailure(
            'This order is ${latest.statusLabel.toLowerCase()} now. '
            'It can no longer be cancelled.',
          );
        }

        transaction.update(ref, {
          'status': OrderStatus.cancelled.name,
          'paymentStatus': latest.paymentStatusAfterCancel.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      throw toDataFailure(error);
    }
  }

  @override
  Stream<List<FoodOrder>> watchRestaurantOpenOrders(String restaurantId) {
    // No orderBy, so no extra index is needed. We sort on the phone.
    return _orders
        .where('restaurantId', isEqualTo: restaurantId)
        .where(
          'status',
          whereIn: [for (final s in OrderStatus.restaurantOpen) s.name],
        )
        .snapshots()
        .map((snapshot) {
          final orders = _toOrders(snapshot);
          orders.sort(_oldestFirst);
          return orders;
        })
        .mapErrorsToDataFailure();
  }

  @override
  Stream<List<FoodOrder>> watchRestaurantDoneOrders(String restaurantId) {
    // Needs a Firestore index: restaurantId, status, placedAt newest first.
    return _orders
        .where('restaurantId', isEqualTo: restaurantId)
        .where('status', whereIn: [for (final s in OrderStatus.ends) s.name])
        .orderBy('placedAt', descending: true)
        .limit(maxDoneOrders)
        .snapshots()
        .map(_toOrders)
        .mapErrorsToDataFailure();
  }

  @override
  Future<void> moveOrder(FoodOrder order, OrderStatus next) async {
    final ref = _orders.doc(order.id);

    try {
      // Reads the latest status first. The customer may cancel
      // at the same moment.
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(ref);
        final data = doc.data();
        if (!doc.exists || data == null) {
          throw const DataFailure('This order was not found.');
        }

        final latest = OrderModel.fromMap(doc.id, data);
        if (!latest.canRestaurantMoveTo(next)) {
          throw DataFailure(_stepRefusedMessage(latest));
        }

        transaction.update(ref, {
          'status': next.name,
          'paymentStatus': latest.paymentStatusAfter(next).name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      throw toDataFailure(error);
    }
  }

  static String _stepRefusedMessage(FoodOrder latest) {
    if (latest.status == OrderStatus.cancelled) {
      return 'The customer cancelled this order.';
    }
    return 'This order is ${latest.statusLabel.toLowerCase()} now. '
        'Please check the list.';
  }

  static List<FoodOrder> _toOrders(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  // An order still waiting for its server time is the newest.
  static int _oldestFirst(FoodOrder a, FoodOrder b) {
    final aTime = a.placedAt;
    final bTime = b.placedAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return aTime.compareTo(bTime);
  }
}