import 'package:flutter/material.dart';

// Flutter equivalents of the CSS variables defined in globals.css (:root { ... })
abstract final class AppColors {
  // Light mode primary  →  --site-accent: #4f46e5
  static const Color primary = Color(0xFF4F46E5);

  // Gradient end color  →  --site-action-end: #0e7490
  static const Color gradientEnd = Color(0xFF0E7490);

  // Muted / secondary text  →  --site-muted-text: #475569
  static const Color mutedText = Color(0xFF475569);

  // Input and card border  →  --site-border: #cbd5e1
  static const Color border = Color(0xFFCBD5E1);

  // Semi-transparent card border  →  --site-navbar-border: rgba(79,70,229,0.24)
  static const Color cardBorder = Color(0x3D4F46E5);

  // Dark mode primary  →  --site-accent (dark): #d97757
  static const Color primaryDark = Color(0xFFD97757);
}

abstract final class AppGradients {
  // Button gradient  →  linear-gradient(135deg, #4f46e5, #0e7490)
  static const LinearGradient action = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.gradientEnd],
  );
}

abstract final class AppTheme {
  static ThemeData light() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary, // matches web's #4f46e5 indigo
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
  }
}
