import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

// Shows a food or restaurant photo. Shows a soft orange box when there is none.
class FoodImage extends StatelessWidget {
  const FoodImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.iconSize = 40,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl.isEmpty ? _defaultBox() : _photo(),
      ),
    );
  }

  Widget _photo() {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      // Show the default box while loading and if the link is broken.
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _defaultBox(),
      errorBuilder: (context, error, stackTrace) => _defaultBox(),
    );
  }

  Widget _defaultBox() {
    return ColoredBox(
      color: AppTheme.brandOrange.withValues(alpha: 0.12),
      child: Center(
        child: Icon(
          Icons.fastfood_rounded,
          size: iconSize,
          color: AppTheme.brandOrange,
        ),
      ),
    );
  }
}