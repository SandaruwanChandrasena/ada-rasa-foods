import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

// soft: orange icon on soft orange, for white pages.
// onPhoto: dark icon on white, so it shows on any photo.
enum RoundIconStyle { soft, onPhoto }

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
    final isSoft = style == RoundIconStyle.soft;

    return Container(
      width: iconSize + padding,
      height: iconSize + padding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSoft ? AppTheme.softOrange : Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: isSoft ? AppTheme.brandOrange : AppTheme.textDark,
      ),
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
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: RoundIconCircle(icon: icon, style: style),
    );
  }
}