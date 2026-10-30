// Exact status names from the PRD. Firestore saves the enum name.
enum OrderStatus {
  placed,
  accepted,
  preparing,
  ready,
  completed,
  riderAssigned,
  pickedUp,
  delivered,
  rejected,
  cancelled;

  // The steps a pickup order goes through (Stage 1).
  static const List<OrderStatus> pickupSteps = [
    placed,
    accepted,
    preparing,
    ready,
    completed,
  ];

  // No status can change after an end state.
  bool get isEnd =>
      this == completed ||
      this == delivered ||
      this == rejected ||
      this == cancelled;

  // One value, two labels: "ready" depends on pickup or delivery.
  String labelFor(Fulfillment fulfillment) {
    return switch (this) {
      placed => 'Placed',
      accepted => 'Accepted',
      preparing => 'Preparing',
      ready =>
        fulfillment == Fulfillment.pickup ? 'Ready for pickup' : 'Ready',
      completed => 'Completed',
      riderAssigned => 'Rider assigned',
      pickedUp => 'Picked up',
      delivered => 'Delivered',
      rejected => 'Rejected',
      cancelled => 'Cancelled',
    };
  }
}

// Stage 1 has pickup only. Delivery comes in Stage 2.
enum Fulfillment { pickup, delivery }

enum PaymentMethod { cash, card }

// No "failed" value: a failed card payment places no order.
enum PaymentStatus { pending, paid, refunded }