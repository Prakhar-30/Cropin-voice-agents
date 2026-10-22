import 'package:flutter/material.dart';

/// Colours and styles taken from the Cropin Grow mobile app.
class CropinColors {
  static const header = Color(0xFF24475A);
  static const primary = Color(0xFF24475A);
  static const green = Color(0xFF79BE2A);
  static const goodGreen = Color(0xFF72B026);
  static const attention = Color(0xFFD5532B);
  static const text = Color(0xFF1D1D1D);
  static const subText = Color(0xFF5F6368);
  static const hint = Color(0xFF8A8F94);
  static const border = Color(0xFFC6CCD1);
  static const divider = Color(0xFFEDF0F2);
  static const searchFill = Color(0xFFEFF1F3);
  static const chipGrey = Color(0xFFB9BDC1);
  static const required = Color(0xFFE53935);

  // Farm Intelligence & Advisory cards
  static const cropHealth = Color(0xFF6C6BD9);
  static const cropHealthDark = Color(0xFF2E2A7A);
  static const yield = Color(0xFF5B8DE0);
  static const yieldDark = Color(0xFF0E2F78);
  static const weather = Color(0xFF4EC4DE);
  static const weatherDark = Color(0xFF115F72);
  static const indices = Color(0xFFA24FDF);
  static const indicesDark = Color(0xFF5A1A8E);
  static const pest = Color(0xFFE5894A);
  static const pestDark = Color(0xFF7A3610);

  // Voice agent accents
  static const voiceFilled = Color(0xFF2E9E5B);
  static const voiceCheck = Color(0xFFF2A100);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: CropinColors.primary,
        primary: CropinColors.primary,
        secondary: CropinColors.green,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.white,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: CropinColors.header,
        foregroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white),
      ),
      dividerColor: CropinColors.divider,
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: CropinColors.subText, width: 1.6),
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? CropinColors.primary : Colors.transparent),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
