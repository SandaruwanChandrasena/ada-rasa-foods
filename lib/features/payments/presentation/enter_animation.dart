import 'package:material_ui/material_ui.dart';

// The same curve as CSS cubic-bezier(0.22, 1, 0.36, 1).
const Curve smoothCurve = Cubic(0.22, 1, 0.36, 1);

// Plays a small "enter" animation once, when it is first built.
// A new key makes a new State, so the animation plays again.
// Example: EnterAnimation(key: ValueKey('3-7'), from: Offset(0, 12), ...)
class EnterAnimation extends StatelessWidget {
  const EnterAnimation({
    super.key,
    required this.child,
    this.from = Offset.zero,
    this.scaleFrom = 1.0,
    this.duration = const Duration(milliseconds: 300),
    this.curve = smoothCurve,
  });

  final Widget child;

  // Start position in pixels. It moves to Offset.zero.
  final Offset from;

  // Start size. It grows to 1.0.
  final double scaleFrom;

  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    // Respects the phone setting "remove animations".
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : duration,
      curve: curve,
      child: child,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset.lerp(from, Offset.zero, t)!,
            child: Transform.scale(
              scale: scaleFrom + (1 - scaleFrom) * t,
              child: child,
            ),
          ),
        );
      },
    );
  }
}