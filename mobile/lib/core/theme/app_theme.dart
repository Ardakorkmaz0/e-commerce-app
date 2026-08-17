import 'package:flutter/material.dart';

// Flutter equivalents of the CSS variables defined in globals.css.
// The light values come from `:root`, the dark ones from
// `[data-bs-theme="dark"]`, so both apps read as the same product.
abstract final class AppColors {
  // ── Light  →  :root ────────────────────────────────────────────────
  static const Color primary = Color(0xFF4F46E5); // --site-accent
  static const Color gradientEnd = Color(0xFF0E7490); // --site-action-end
  static const Color mutedText = Color(0xFF475569); // --site-muted-text
  static const Color border = Color(0xFFCBD5E1); // --site-border
  static const Color cardBorder = Color(0x3D4F46E5); // --site-navbar-border
  static const Color surface = Color(0xFFFFFFFF); // --site-input-bg
  static const Color controlBackground = Color(0xFFEEF2FF); // --site-control-bg

  // ── Dark  →  [data-bs-theme="dark"] ────────────────────────────────
  static const Color primaryDark = Color(0xFFD97757); // --site-accent
  static const Color gradientEndDark = Color(0xFFBD5D3A); // --site-action-end
  static const Color mutedTextDark = Color(0xFFA3A09A); // --site-muted-text
  static const Color borderDark = Color(0xFF3E3E3B); // --site-border
  static const Color cardBorderDark = Color(0x1AFAF9F5); // --site-navbar-border
  static const Color surfaceDark = Color(0xFF1F1E1D); // --site-input-bg
  static const Color controlBackgroundDark = Color(0xFF30302E); // --site-control-bg
  static const Color textDark = Color(0xFFFAF9F5); // --site-text
}

/// Resolves a token for the brightness currently in effect.
///
/// Widgets call these instead of the raw constants so one written screen
/// works in both themes.
extension AppThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get accent => isDark ? AppColors.primaryDark : AppColors.primary;
  Color get mutedText => isDark ? AppColors.mutedTextDark : AppColors.mutedText;
  Color get borderColor => isDark ? AppColors.borderDark : AppColors.border;
  Color get fieldFill => isDark ? AppColors.surfaceDark : AppColors.surface;
  Color get controlBackground =>
      isDark ? AppColors.controlBackgroundDark : AppColors.controlBackground;
}

abstract final class AppGradients {
  static const LinearGradient action = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.gradientEnd],
  );

  static const LinearGradient actionDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryDark, AppColors.gradientEndDark],
  );

  static LinearGradient of(BuildContext context) =>
      context.isDark ? actionDark : action;
}

abstract final class AppTheme {
  static ThemeData light() => _build(
    brightness: Brightness.light,
    seed: AppColors.primary,
    surface: AppColors.surface,
    border: AppColors.border,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    seed: AppColors.primaryDark,
    surface: AppColors.surfaceDark,
    border: AppColors.borderDark,
  );

  /// One builder for both themes, so a change to input styling or card
  /// shape cannot land in only one of them.
  static ThemeData _build({
    required Brightness brightness,
    required Color seed,
    required Color surface,
    required Color border,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // Fields pick their fill up from here, which is why screens no longer
      // hardcode a white background.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: seed, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: brightness == Brightness.dark ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border.withValues(alpha: 0.6)),
        ),
      ),
      dividerTheme: DividerThemeData(color: border),
    );
  }
}
