import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'round_icon_button.dart';

// Builds the right side button. It gets the style to use right now.
typedef PhotoHeaderTrailing = Widget Function(RoundIconStyle style);

// A big photo at the top of a page. On scroll it fades to a white bar
// with the title, and the buttons turn from white to soft orange.
// The clock and battery sit on a fixed colour strip, never on the photo.
class PhotoHeader extends StatelessWidget {
  const PhotoHeader({
    super.key,
    required this.title,
    required this.photo,
    this.height = 220,
    this.trailing,
  });

  // Past this much of the scroll, the bar is treated as white.
  static const double solidFrom = 0.6;

  // The strip behind the clock and battery. Change here to try another.
  static const Color stripColor = AppTheme.brandOrange;

  // How far the white page curves up over the bottom of the photo.
  static const double curve = 20;

  // White icons on a dark strip, dark icons on a light strip.
  static SystemUiOverlayStyle get statusIcons =>
      ThemeData.estimateBrightnessForColor(stripColor) == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark;

  final String title;
  final Widget photo;
  final double height;
  final PhotoHeaderTrailing? trailing;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _PhotoHeaderDelegate(
        title: title,
        photo: photo,
        height: height,
        topPadding: MediaQuery.paddingOf(context).top,
        trailing: trailing,
      ),
    );
  }
}

class _PhotoHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PhotoHeaderDelegate({
    required this.title,
    required this.photo,
    required this.height,
    required this.topPadding,
    required this.trailing,
  });

  final String title;
  final Widget photo;
  final double height;
  final double topPadding;
  final PhotoHeaderTrailing? trailing;

  @override
  double get minExtent => kToolbarHeight + topPadding;

  @override
  double get maxExtent => height + topPadding;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtent - minExtent;
    // 0 = full photo, 1 = white bar.
    final t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final solid = t >= PhotoHeader.solidFrom;
    final style = solid ? RoundIconStyle.soft : RoundIconStyle.onPhoto;
    final titleAlpha =
        ((t - PhotoHeader.solidFrom) / (1 - PhotoHeader.solidFrom))
            .clamp(0.0, 1.0);
    final barIconSize = Theme.of(context).appBarTheme.iconTheme?.size;

    final layers = Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(top: topPadding, child: photo),
        // A colour layer, not Opacity, so scrolling stays smooth.
        Positioned.fill(
          top: topPadding,
          child: ColoredBox(color: Colors.white.withValues(alpha: t)),
        ),
        // The white page curving up over the photo.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: PhotoHeader.curve,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(PhotoHeader.curve),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: topPadding,
          child: const ColoredBox(color: PhotoHeader.stripColor),
        ),
        Positioned(
          left: 4,
          right: 4,
          top: topPadding,
          height: kToolbarHeight,
          child: IconButtonTheme(
            data: IconButtonThemeData(
              style: IconButton.styleFrom(iconSize: barIconSize),
            ),
            child: Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  style: style,
                  onPressed: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textDark.withValues(alpha: titleAlpha),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                trailing?.call(style) ?? const SizedBox(width: 48),
              ],
            ),
          ),
        ),
        // A thin line under the white bar.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 1,
          child: ColoredBox(
            color: AppTheme.border.withValues(alpha: titleAlpha),
          ),
        ),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: PhotoHeader.statusIcons,
      child: layers,
    );
  }

  @override
  bool shouldRebuild(_PhotoHeaderDelegate oldDelegate) => true;
}