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

// Flies a small food photo from [context] to the cart icon (CUS-7).
// Does nothing when no cart icon is on the screen, like on the cart page.
void flyToCart(BuildContext context, {required String imageUrl}) {
  CartFlyTarget? target;
  Offset? end;
  // The newest icon belongs to the newest page.
  for (final candidate in _targets.reversed) {
    end = candidate.centerOnScreen;
    if (end != null) {
      target = candidate;
      break;
    }
  }

  final startBox = context.findRenderObject();
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (target == null ||
      end == null ||
      overlay == null ||
      startBox is! RenderBox ||
      !startBox.attached) {
    return;
  }

  final start = startBox.localToGlobal(startBox.size.center(Offset.zero));
  final landedTarget = target;
  final landedEnd = end;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyingPhoto(
      imageUrl: imageUrl,
      start: start,
      end: landedEnd,
      onDone: () {
        entry.remove();
        landedTarget.bounce();
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
    required this.onDone,
  });

  final String imageUrl;
  final Offset start;
  final Offset end;
  final VoidCallback onDone;

  @override
  State<_FlyingPhoto> createState() => _FlyingPhotoState();
}

class _FlyingPhotoState extends State<_FlyingPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
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
          // Goes up a little in the middle, so it flies in an arc.
          final lift = math.sin(t * math.pi) * 80;
          final size = 56 - 32 * t;

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