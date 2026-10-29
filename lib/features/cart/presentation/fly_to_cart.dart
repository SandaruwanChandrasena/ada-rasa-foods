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

// Fast taps: at most 4 photos in the air, and a short gap between them.
// Extra taps still change the cart, they only skip the photo.
const int _maxFlights = 4;
const Duration _minGap = Duration(milliseconds: 90);

final _cartFlights = _FlightLimiter();
final _binFlights = _FlightLimiter();

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
      !_cartFlights.tryStart()) {
    return;
  }

  final (target, end) = found;
  final start = startBox.localToGlobal(startBox.size.center(Offset.zero));

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyingPhoto(
      imageUrl: imageUrl,
      start: start,
      end: end,
      startSize: 52,
      endSize: 22,
      lift: 70,
      duration: const Duration(milliseconds: 550),
      onDone: () {
        entry.remove();
        _cartFlights.finish();
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
  if (found == null || overlay == null || !_binFlights.tryStart()) return;

  final (_, bag) = found;
  final bin = bag + const Offset(-46, 0);

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
      startSize: 24,
      endSize: 12,
      lift: 32,
      duration: const Duration(milliseconds: 420),
      onDone: () {
        entry.remove();
        _binFlights.finish();
        final binState = _binKey.currentState;
        binState?.shake();
        // The last photo is in, so the bin can go away.
        if (_binFlights.active == 0) binState?.closeSoon();
      },
    ),
  );
  overlay.insert(entry);
}

// Counts photos in the air, and keeps a short gap between new ones.
class _FlightLimiter {
  int active = 0;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  bool tryStart() {
    final now = DateTime.now();
    if (active >= _maxFlights || now.difference(_last) < _minGap) {
      return false;
    }
    active++;
    _last = now;
    return true;
  }

  void finish() {
    if (active > 0) active--;
  }
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
    curve: Curves.easeInOutCubic,
  );

  late final Animation<double> _fade =
      Tween<double>(begin: 1, end: 0.6).animate(_controller);

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
    final size = widget.startSize;
    final endScale = widget.endSize / size;
    final travel = widget.end - widget.start;

    // Placed once. Each frame only moves and scales it (no new layout).
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: widget.start.dx - size / 2,
            top: widget.start.dy - size / 2,
            width: size,
            height: size,
            child: AnimatedBuilder(
              animation: _progress,
              builder: (context, child) {
                final t = _progress.value;
                final lift = math.sin(t * math.pi) * widget.lift;
                return Transform.translate(
                  offset: Offset(travel.dx * t, travel.dy * t - lift),
                  child: Transform.scale(
                    scale: 1 + (endScale - 1) * t,
                    child: child,
                  ),
                );
              },
              // Drawn once and reused on every frame.
              child: FadeTransition(
                opacity: _fade,
                child: RepaintBoundary(
                  child: ClipOval(
                    child: FoodImage(
                      imageUrl: widget.imageUrl,
                      borderRadius: 0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
  static const double _size = 36;

  // Grows in when shown, shrinks away when closed.
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  late final Animation<double> _grow = CurvedAnimation(
    parent: _appear,
    curve: Curves.easeOutBack,
  );

  // A small left and right shake when a photo lands.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  late final Animation<double> _turns = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: -0.035), weight: 25),
    TweenSequenceItem(tween: Tween(begin: -0.035, end: 0.035), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 0.035, end: 0), weight: 25),
  ]).animate(_shake);

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

  // On fast taps, let a running shake finish so it does not jump.
  void shake() {
    if (!_shake.isAnimating) _shake.forward(from: 0);
  }

  // Waits a little, so the customer sees the photo go in.
  void closeSoon() {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 450), () async {
      await _appear.reverse();
      if (mounted && _appear.value == 0) widget.onClosed();
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
    final colors = Theme.of(context).colorScheme;

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
                // Same look as the bag: no background of its own (so the top
                // bar shows through), bag icon color, and a red round border.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade700, width: 1.5),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 22,
                    color: colors.onSurfaceVariant,
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