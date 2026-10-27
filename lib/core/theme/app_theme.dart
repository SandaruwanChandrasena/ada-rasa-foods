import 'package:material_ui/material_ui.dart';

class AppTheme {
  AppTheme._();

  static const Color brandOrange = Color(0xFFFF6B00);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: brandOrange);

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      inputDecorationTheme: InputDecorationThemeData(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}