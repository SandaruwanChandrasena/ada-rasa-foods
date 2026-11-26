import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

// Paints the phone's status bar (clock and battery) orange on every page.
class StatusStrip extends StatelessWidget {
  const StatusStrip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.viewPaddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.statusBarStyle,
      child: Stack(
        children: [
          child,
          // On top of every page and dialog, and it never takes a tap.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: top,
            child: const IgnorePointer(
              child: ColoredBox(color: AppTheme.statusBarColor),
            ),
          ),
        ],
      ),
    );
  }
}