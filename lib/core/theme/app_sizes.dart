// Icon sizes that grow a little on wider phones.
class AppIconSizes {
  const AppIconSizes({required this.bar, required this.body});

  // Icons in the top bar.
  final double bar;

  // All other icons with no size of their own.
  final double body;

  static const small = AppIconSizes(bar: 24, body: 24);
  static const normal = AppIconSizes(bar: 26, body: 25);
  static const large = AppIconSizes(bar: 28, body: 26);

  // The width is in screen points (dp), not pixels.
  static AppIconSizes forWidth(double width) {
    if (width < 360) return small;
    if (width < 400) return normal;
    return large;
  }
}