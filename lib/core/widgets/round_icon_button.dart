import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

// soft: orange icon on soft orange, for white pages.
// onPhoto: dark icon on white, so it shows on any photo.
// danger: red icon on soft red, for actions that cannot be undone.
enum RoundIconStyle { soft, onPhoto, danger }

// A round background with an icon in the middle, and no border.
class RoundIconCircle extends StatelessWidget {
  const RoundIconCircle({
    super.key,
    required this.icon,
    this.style = RoundIconStyle.soft,
  });

  // The circle is this much wider than the icon.
  static const double padding = 12;

  final IconData icon;
  final RoundIconStyle style;

  @override
  Widget build(BuildContext context) {
    // Icon buttons and the top bar set the size for each phone width.
    final iconSize = IconTheme.of(context).size ?? 24;
    final (background, iconColor) = switch (style) {
      RoundIconStyle.soft => (AppTheme.softOrange, AppTheme.brandOrange),
      RoundIconStyle.onPhoto => (Colors.white, AppTheme.textDark),
      RoundIconStyle.danger => (AppTheme.dangerBg, AppTheme.dangerRed),
    };

    return Container(
      width: iconSize + padding,
      height: iconSize + padding,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: iconSize, color: iconColor),
    );
  }
}

// A tappable RoundIconCircle.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.style = RoundIconStyle.soft,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final RoundIconStyle style;

  @override
  Widget build(BuildContext context) {
    final circle = RoundIconCircle(icon: icon, style: style);

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      // A button that cannot be tapped now looks faded.
      icon: onPressed == null ? Opacity(opacity: 0.4, child: circle) : circle,
    );
  }
}