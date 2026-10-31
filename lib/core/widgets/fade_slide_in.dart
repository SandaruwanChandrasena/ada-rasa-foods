import 'package:material_ui/material_ui.dart';

// A soft ease out for every opening animation in the app.
const Curve entranceCurve = Cubic(0.25, 1, 0.5, 1);

// Fades its child in and slides it up a little, after [delay].
// Many of them with growing delays give a "one by one" opening.
// It waits until the page has slid in, so two animations never mix.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.offset = const Offset(0, 16),
    this.scaleFrom = 1.0,
    this.alignment = Alignment.center,
    this.curve = entranceCurve,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  // Start position in pixels. It moves to Offset.zero.
  final Offset offset;

  // Start size. It grows (or shrinks) to 1.0.
  final double scaleFrom;

  // The point the size change grows from.
  final Alignment alignment;

  final Curve curve;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  // One controller for the delay and the animation, so no timers.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );

  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(_delayPart, 1, curve: widget.curve),
  );

  double get _delayPart {
    final total = (widget.delay + widget.duration).inMicroseconds;
    return total == 0 ? 0 : widget.delay.inMicroseconds / total;
  }

  bool _started = false;
  ModalRoute<Object?>? _route;
  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Runs again when the page goes on stage. Then check if we can start.
    if (_started) {
      _startIfSlideInDone();
      return;
    }
    _started = true;

    // Phone setting "remove animations": show it at once.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.value = 1;
      return;
    }

    // In its first frame a new page is "offstage" and its animation says
    // "completed" too early, so we also wait until it is on stage.
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (route == null || animation == null || _slideInDone(route)) {
      _controller.forward();
    } else {
      _route = route;
      _routeAnimation = animation..addStatusListener(_onRouteStatus);
    }
  }

  bool _slideInDone(ModalRoute<Object?> route) =>
      !route.offstage && (route.animation?.isCompleted ?? true);

  void _onRouteStatus(AnimationStatus status) => _startIfSlideInDone();

  void _startIfSlideInDone() {
    final route = _route;
    if (route == null || !_slideInDone(route)) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
    _route = null;
    if (mounted) _controller.forward();
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FadeTransition is light: it does not rebuild the child.
    return FadeTransition(
      opacity: _progress,
      child: AnimatedBuilder(
        animation: _progress,
        child: widget.child,
        builder: (context, child) {
          final t = _progress.value;
          return Transform.translate(
            offset: Offset.lerp(widget.offset, Offset.zero, t)!,
            child: Transform.scale(
              scale: widget.scaleFrom + (1 - widget.scaleFrom) * t,
              alignment: widget.alignment,
              child: child,
            ),
          );
        },
      ),
    );
  }
}