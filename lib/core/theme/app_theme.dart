import 'package:material_ui/material_ui.dart';

class AppTheme {
  AppTheme._();

  // Bright orange from the login design.
  static const Color brandOrange = Color(0xFFFF5000);

  static ThemeData light() {
    // fromSeed alone makes a darker orange, so we set primary ourselves.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandOrange,
      primary: brandOrange,
      onPrimary: Colors.white,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      inputDecorationTheme: InputDecorationThemeData(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}