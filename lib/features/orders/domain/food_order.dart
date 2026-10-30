import 'package:equatable/equatable.dart';

import '../../cart/domain/cart.dart';
import 'order_item.dart';
import 'order_status.dart';

// Called FoodOrder, not Order, so it never clashes with another class.
class FoodOrder extends Equatable {
  const FoodOrder({
    this.id = '',
    required this.customerId,
    required this.customerName,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.items,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    this.fulfillment = Fulfillment.pickup,
    this.status = OrderStatus.placed,
    this.cardBrand = '',
    this.cardLast4 = '',
    this.placedAt,
    this.updatedAt,
  });

  // A new pickup order from the cart (CUS-4).
  factory FoodOrder.fromCart({
    required Cart cart,
    required String customerId,
    required String customerName,
    required String restaurantAddress,
    required PaymentMethod paymentMethod,
    String cardBrand = '',
    String cardLast4 = '',
  }) {
    final isCard = paymentMethod == PaymentMethod.card;

    return FoodOrder(
      customerId: customerId,
      customerName: customerName,
      restaurantId: cart.restaurantId,
      restaurantName: cart.restaurantName,
      restaurantAddress: restaurantAddress,
      items: [for (final item in cart.items) OrderItem.fromCartItem(item)],
      total: cart.total,
      paymentMethod: paymentMethod,
      // A card order is saved only after a successful demo payment.
      paymentStatus: isCard ? PaymentStatus.paid : PaymentStatus.pending,
      cardBrand: isCard ? cardBrand : '',
      cardLast4: isCard ? cardLast4 : '',
    );
  }

  // Empty until Firestore gives the order an id.
  final String id;

  final String customerId;
  final String customerName;

  // Copies of the restaurant details at the time of the order.
  final String restaurantId;
  final String restaurantName;
  final String restaurantAddress;

  final List<OrderItem> items;

  // Whole rupees, calculated in the app (a known PRD limit).
  final int total;

  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final Fulfillment fulfillment;
  final OrderStatus status;

  // "visa" or "mastercard". Empty for cash orders.
  final String cardBrand;
  final String cardLast4;

  final DateTime? placedAt;
  final DateTime? updatedAt;

  // Short order number for people, like "A7K3Q2".
  String get shortNumber {
    final part = id.length > 6 ? id.substring(0, 6) : id;
    return part.toUpperCase();
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  bool get isCard => paymentMethod == PaymentMethod.card;

  String get statusLabel => status.labelFor(fulfillment);

  // The customer can cancel only before the restaurant accepts.
  bool get canCancel => status == OrderStatus.placed;

  // A paid card order is refunded (demo). A cash order stays pending.
  PaymentStatus get paymentStatusAfterCancel =>
      isCard && paymentStatus == PaymentStatus.paid
          ? PaymentStatus.refunded
          : paymentStatus;

  @override
  List<Object?> get props => [
        id,
        customerId,
        customerName,
        restaurantId,
        restaurantName,
        restaurantAddress,
        items,
        total,
        paymentMethod,
        paymentStatus,
        fulfillment,
        status,
        cardBrand,
        cardLast4,
        placedAt,
        updatedAt,
      ];
}