import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/food_image.dart';

// Something the food photo can fly to. The cart icon is one.
abstract class CartFlyTarget {
  // Center of the target on the screen. Null if it is not on the top page.
  Offset? get centerOnScreen;

  // Plays the bounce after the photo lands.
  void bounce();
}

final List<CartFlyTarget> _targets = [];

void registerCartTarget(CartFlyTarget target) => _targets.add(target);

void unregisterCartTarget(CartFlyTarget target) => _targets.remove(target);

// Most photos in the air at the same time. More taps still change the
// cart, they just skip the animation, so the app stays smooth.
const int _maxFlights = 4;
int _flightsToCart = 0;
int _flightsToBin = 0;

// One shared dustbin next to the bag, for many quick minus taps.
OverlayEntry? _binEntry;
final GlobalKey<_DustbinState> _binKey = GlobalKey<_DustbinState>();

// The cart icon on the page the customer sees now, and its center.
(CartFlyTarget, Offset)? _currentTarget() {
  // The newest icon belongs to the newest page.
  for (final target in _targets.reversed) {
    final center = target.centerOnScreen;
    if (center != null) return (target, center);
  }
  return null;
}

// Flies a small food photo from [context] to the cart icon (CUS-7).
// Does nothing when no cart icon is on the screen, like on the cart page.
void flyToCart(BuildContext context, {required String imageUrl}) {
  final found = _currentTarget();
  final startBox = context.findRenderObject();
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (found == null ||
      overlay == null ||
      startBox is! RenderBox ||
      !startBox.attached ||
      _flightsToCart >= _maxFlights) {
    return;
  }

  final (target, end) = found;
  final start = startBox.localToGlobal(startBox.size.center(Offset.zero));
  _flightsToCart++;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyingPhoto(
      imageUrl: imageUrl,
      start: start,
      end: end,
      startSize: 56,
      endSize: 24,
      lift: 80,
      duration: const Duration(milliseconds: 650),
      onDone: () {
        entry.remove();
        _flightsToCart--;
        target.bounce();
      },
    ),
  );
  overlay.insert(entry);
}

// Minus on the menu: a photo leaves the bag and drops into a dustbin
// that shows next to the bag for a moment.
void flyToBin(BuildContext context, {required String imageUrl}) {
  final found = _currentTarget();
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (found == null || overlay == null || _flightsToBin >= _maxFlights) {
    return;
  }

  final (_, bag) = found;
  final bin = bag + const Offset(-48, 4);
  _flightsToBin++;

  // Show the bin, or keep it open if it is already there.
  if (_binEntry == null) {
    final binEntry = OverlayEntry(
      builder: (_) => _Dustbin(
        key: _binKey,
        center: bin,
        onClosed: () {
          _binEntry?.remove();
          _binEntry = null;
        },
      ),
    );
    _binEntry = binEntry;
    overlay.insert(binEntry);
  } else {
    _binKey.currentState?.open();
  }

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyingPhoto(
      imageUrl: imageUrl,
      start: bag,
      end: bin,
      startSize: 26,
      endSize: 14,
      lift: 36,
      duration: const Duration(milliseconds: 450),
      onDone: () {
        entry.remove();
        _flightsToBin--;
        final binState = _binKey.currentState;
        binState?.shake();
        // The last photo is in, so the bin can go away.
        if (_flightsToBin == 0) binState?.closeSoon();
      },
    ),
  );
  overlay.insert(entry);
}

class _FlyingPhoto extends StatefulWidget {
  const _FlyingPhoto({
    required this.imageUrl,
    required this.start,
    required this.end,
    required this.startSize,
    required this.endSize,
    required this.lift,
    required this.duration,
    required this.onDone,
  });

  final String imageUrl;
  final Offset start;
  final Offset end;
  final double startSize;
  final double endSize;

  // How high the arc goes in the middle.
  final double lift;

  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_FlyingPhoto> createState() => _FlyingPhotoState();
}

class _FlyingPhotoState extends State<_FlyingPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward().whenComplete(widget.onDone));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) {
          final t = _progress.value;
          final point = Offset.lerp(widget.start, widget.end, t)!;
          final lift = math.sin(t * math.pi) * widget.lift;
          final size =
              widget.startSize + (widget.endSize - widget.startSize) * t;

          return Stack(
            children: [
              Positioned(
                left: point.dx - size / 2,
                top: point.dy - size / 2 - lift,
                width: size,
                height: size,
                child: Opacity(opacity: 1 - 0.4 * t, child: child),
              ),
            ],
          );
        },
        // Built once, not on every frame.
        child: Material(
          elevation: 4,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: FoodImage(imageUrl: widget.imageUrl, borderRadius: 0),
        ),
      ),
    );
  }
}

class _Dustbin extends StatefulWidget {
  const _Dustbin({super.key, required this.center, required this.onClosed});

  final Offset center;
  final VoidCallback onClosed;

  @override
  State<_Dustbin> createState() => _DustbinState();
}

class _DustbinState extends State<_Dustbin> with TickerProviderStateMixin {
  static const double _size = 34;

  // Grows in when shown, shrinks away when closed.
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  // A small left and right shake when a photo lands.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  late final Animation<double> _turns = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: -0.04), weight: 25),
    TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.04), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 0.04, end: 0), weight: 25),
  ]).animate(_shake);

  late final Animation<double> _grow = CurvedAnimation(
    parent: _appear,
    curve: Curves.easeOutBack,
  );

  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    open();
  }

  void open() {
    _closeTimer?.cancel();
    _appear.forward();
  }

  void shake() => _shake.forward(from: 0);

  // Waits a little, so the customer sees the photo go in.
  void closeSoon() {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 450), () async {
      await _appear.reverse();
      if (mounted && !_appear.isAnimating && _appear.value == 0) {
        widget.onClosed();
      }
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _appear.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: widget.center.dx - _size / 2,
          top: widget.center.dy - _size / 2,
          width: _size,
          height: _size,
          child: IgnorePointer(
            child: ScaleTransition(
              scale: _grow,
              child: RotationTransition(
                turns: _turns,
                child: Material(
                  color: Colors.white,
                  elevation: 3,
                  shape: const CircleBorder(),
                  child: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}