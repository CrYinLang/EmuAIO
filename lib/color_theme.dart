import 'package:flutter/material.dart';

class AppColors {
  static const Color black = Colors.black;
  static const Color white = Colors.white;
  static const Color transparent = Colors.transparent;

  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  static const Color primary = Color(0xFF4DB6AC);
  static const Color primaryLight = Color(0xFF80CBC4);
  static const Color primaryDark = Color(0xFF004D40);
  static const Color secondary = Color(0xFF80CBC4);
  static const Color error = Color(0xFFCF6679);

  static const Color matchHigh = Colors.green;
  static const Color matchMedium = Colors.orange;
  static const Color matchLow = Colors.red;

  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);
}

class ColorThemeUtils {
  static ThemeData buildMidnightTheme() {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: AppColors.black,
      canvasColor: AppColors.black,
      cardColor: AppColors.grey900,
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.grey900,
      ),
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.black,
        primaryContainer: AppColors.primaryDark,
        onPrimaryContainer: AppColors.white,
        secondary: AppColors.secondary,
        onSecondary: AppColors.black,
        secondaryContainer: AppColors.primaryDark,
        onSecondaryContainer: AppColors.white,
        surface: AppColors.grey900,
        onSurface: AppColors.white,
        surfaceContainerHighest: AppColors.grey800,
        onSurfaceVariant: AppColors.grey300,
        error: AppColors.error,
        onError: AppColors.black,
        outline: AppColors.grey700,
        outlineVariant: AppColors.grey800,
        shadow: AppColors.black,
        scrim: const Color.fromRGBO(0, 0, 0, 0.54),
        inverseSurface: AppColors.grey300,
        onInverseSurface: AppColors.black,
        inversePrimary: const Color(0xFF00695C),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.grey900,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.grey900,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.grey400,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.grey900,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        margin: EdgeInsets.all(8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.grey900,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.grey700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.grey700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.grey500;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color.fromRGBO(77, 182, 172, 0.5);
          }
          return AppColors.grey500;
        }),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: AppColors.grey900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.grey800,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ColorScheme get lightColorScheme {
    return const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.error,
    );
  }

  static ColorScheme get darkColorScheme {
    return const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.error,
    );
  }

  static Color getMatchColor(double score) {
    if (score >= 0.8) return AppColors.matchHigh;
    if (score >= 0.6) return AppColors.matchMedium;
    return AppColors.matchLow;
  }

  static Color getAdaptiveTextColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? AppColors.white : AppColors.grey900;
  }

  static Color getCardColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? AppColors.grey900 : AppColors.white;
  }
}