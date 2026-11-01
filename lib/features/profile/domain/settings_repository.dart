// App settings saved on this phone (not per user). Read once at start.
abstract class SettingsRepository {
  // True when the customer turned on "Reduce animations" in the app.
  bool get reduceAnimations;

  Future<void> setReduceAnimations(bool value);
}