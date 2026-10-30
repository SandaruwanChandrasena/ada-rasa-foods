// Remembers, on this phone, which rejected orders the customer opened.
// The home banner hides a rejected order once it is seen.
abstract class SeenOrderRepository {
  // Gives an empty set if nothing is saved.
  Future<Set<String>> loadSeen(String userId);

  Future<void> markSeen(String userId, String orderId);
}