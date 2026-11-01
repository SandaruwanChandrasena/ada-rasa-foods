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

  // Orders the restaurant still works on (New and Active tabs).
  static const List<OrderStatus> restaurantOpen = [
    placed,
    accepted,
    preparing,
    ready,
  ];

  // End states. No status can change after one of these.
  static const List<OrderStatus> ends = [
    completed,
    delivered,
    rejected,
    cancelled,
  ];

  bool get isEnd => ends.contains(this);

  // The steps the restaurant owner may take (RES-2, RES-5).
  // Only a pickup order is completed by the restaurant.
  List<OrderStatus> restaurantStepsFor(Fulfillment fulfillment) {
    return switch (this) {
      placed => const [accepted, rejected],
      accepted => const [preparing],
      preparing => const [ready],
      ready when fulfillment == Fulfillment.pickup => const [completed],
      _ => const [],
    };
  }

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