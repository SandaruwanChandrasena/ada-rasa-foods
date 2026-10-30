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

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  @override
  Future<String> placeOrder(FoodOrder order) async {
    try {
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
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
              .toList(),
        )
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
}