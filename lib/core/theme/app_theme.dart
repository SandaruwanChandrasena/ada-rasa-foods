import 'package:material_ui/material_ui.dart';

import 'app_sizes.dart';

class AppTheme {
  AppTheme._();

  // Bright orange from the login design.
  static const Color brandOrange = Color(0xFFFF5000);

  // Shared colours, so every screen looks the same.
  static const Color softOrange = Color(0xFFFFEDE3);
  static const Color deepOrange = Color(0xFFC23D00);
  static const Color textDark = Color(0xFF1D1D1F);
  static const Color textMuted = Color(0xFF6B6B6B);
  static const Color border = Color(0xFFE6E6E6);
  static const Color successGreen = Color(0xFF17663A);
  static const Color successBg = Color(0xFFE6F6EC);
  static const Color dangerRed = Color(0xFFA32D2D);
  static const Color dangerBg = Color(0xFFFDE8E8);

  static ThemeData light({AppIconSizes iconSizes = AppIconSizes.normal}) {
    // fromSeed alone makes a darker orange, so we set primary ourselves.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandOrange,
      primary: brandOrange,
      onPrimary: Colors.white,
      surface: Colors.white,
    );

    OutlineInputBorder fieldBorder(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    final barIcons = IconThemeData(color: textDark, size: iconSizes.bar);

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      iconTheme: IconThemeData(size: iconSizes.body),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(iconSize: iconSizes.body),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: barIcons,
        actionsIconTheme: barIcons,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        border: fieldBorder(border),
        enabledBorder: fieldBorder(border),
        disabledBorder: fieldBorder(border),
        focusedBorder: fieldBorder(brandOrange, width: 1.5),
        errorBorder: fieldBorder(colorScheme.error),
        focusedErrorBorder: fieldBorder(colorScheme.error, width: 1.5),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// Gives every screen the theme with icon sizes for this phone's width.
class AppThemeByWidth extends StatelessWidget {
  const AppThemeByWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Theme(
      data: AppTheme.light(iconSizes: AppIconSizes.forWidth(width)),
      child: child,
    );
  }
}