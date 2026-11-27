import 'package:material_ui/material_ui.dart';

// Grey cards with a soft moving shine, shown while restaurants load.
class RestaurantSkeletonList extends StatefulWidget {
  const RestaurantSkeletonList({super.key, this.count = 3});

  final int count;

  @override
  State<RestaurantSkeletonList> createState() =>
      _RestaurantSkeletonListState();
}

class _RestaurantSkeletonListState extends State<RestaurantSkeletonList>
    with SingleTickerProviderStateMixin {
  // One controller moves the shine on every card.
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Phone setting "remove animations": plain grey boxes, no shine.
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduceMotion) {
      _shine.stop();
    } else if (!_shine.isAnimating) {
      _shine.repeat();
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading restaurants',
      child: RepaintBoundary(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: widget.count,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            if (_reduceMotion) return const RestaurantCardSkeleton();
            return AnimatedBuilder(
              animation: _shine,
              builder: (context, _) =>
                  RestaurantCardSkeleton(shine: _shine.value),
            );
          },
        ),
      ),
    );
  }
}

// One grey card, shaped like RestaurantCard.
class RestaurantCardSkeleton extends StatelessWidget {
  const RestaurantCardSkeleton({super.key, this.shine});

  // Where the shine is, from 0 (left) to 1 (right). Null means no shine.
  final double? shine;

  static const Color shineColor = Color(0xFFF8F8F8);

  static Color get baseColor => Colors.grey.shade200;

  @override
  Widget build(BuildContext context) {
    final shapes = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _box(height: 150, widthFactor: 1, radius: 0),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _box(height: 16, widthFactor: 0.55),
              const SizedBox(height: 8),
              _box(height: 12, widthFactor: 0.3),
              const SizedBox(height: 10),
              _box(height: 12, widthFactor: 0.75),
            ],
          ),
        ),
      ],
    );

    final value = shine;

    // Card has a 4 px margin, so we use the same here.
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: value == null
            ? shapes
            : ShaderMask(
                // Paints the moving gradient only on the grey shapes.
                blendMode: BlendMode.srcATop,
                shaderCallback: (bounds) =>
                    _gradient(value).createShader(bounds),
                child: shapes,
              ),
      ),
    );
  }

  Widget _box({
    required double height,
    required double widthFactor,
    double radius = 6,
  }) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  LinearGradient _gradient(double value) {
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [baseColor, shineColor, baseColor],
      stops: const [0.35, 0.5, 0.65],
      // Moves the light band from off the left side to off the right side.
      transform: _SlideGradient(value * 2 - 1),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.part);

  final double part;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * part, 0, 0);
  }
}