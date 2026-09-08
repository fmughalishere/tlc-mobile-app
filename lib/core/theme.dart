import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';

/// The app's one theme, built to match the website rather than to look like
/// stock Material.
///
/// ── Two typefaces, chosen by language, not by mood ──
///
/// Manrope carries Latin text; Noto Nastaliq Urdu carries Urdu. This is not a
/// stylistic pairing — the Latin faces contain no Urdu glyphs at all, so
/// without the second family every Urdu screen would silently fall back to
/// whatever the phone happens to have, which on most Android handsets is a
/// naskh face that Pakistani readers find wrong for body text.
///
/// Nastaliq also needs more vertical room than Latin: its letters cascade
/// downward within a word, so a line height that looks generous in English
/// clips descenders in Urdu. That is why `_urduTextTheme` exists rather than
/// simply swapping the font family.
class AppTheme {
  const AppTheme._();

  /// Latin — the default.
  static ThemeData light() => _base(
        textTheme: GoogleFonts.manropeTextTheme(_scale(ThemeData.light().textTheme)),
      );

  /// Urdu — same colours, different family and more line height.
  static ThemeData urdu() => _base(
        textTheme: GoogleFonts.notoNastaliqUrduTextTheme(
          _urduScale(ThemeData.light().textTheme),
        ),
      );

  static ThemeData _base({required TextTheme textTheme}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Palette.indigo,
      brightness: Brightness.light,
    ).copyWith(
      primary: Palette.indigo,
      onPrimary: Palette.paper,
      secondary: Palette.crimson,
      onSecondary: Palette.paper,
      surface: Palette.paper,
      onSurface: Palette.ink,
      error: Palette.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Palette.paper,
      textTheme: textTheme,

      appBarTheme: const AppBarTheme(
        backgroundColor: Palette.paper,
        foregroundColor: Palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
      ),

      // Crimson, pill-shaped, and never full-width by default — the same
      // shape the website's primary button has.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Palette.crimson,
          foregroundColor: Palette.paper,
          disabledBackgroundColor: Palette.crimson.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Palette.indigoDeep,
          side: const BorderSide(color: Palette.line),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: const StadiumBorder(),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Palette.indigo),
      ),

      cardTheme: CardThemeData(
        color: Palette.paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Palette.line),
          borderRadius: BorderRadius.circular(Palette.radiusCard),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Palette.paperDim,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: _fieldBorder(Palette.line),
        enabledBorder: _fieldBorder(Palette.line),
        focusedBorder: _fieldBorder(Palette.indigo, width: 1.6),
        errorBorder: _fieldBorder(Palette.danger),
        focusedErrorBorder: _fieldBorder(Palette.danger, width: 1.6),
        hintStyle: const TextStyle(color: Palette.inkSoft),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: Palette.mist,
        selectedColor: Palette.indigo,
        labelStyle: const TextStyle(color: Palette.ink),
        secondaryLabelStyle: const TextStyle(color: Palette.paper),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),

      dividerTheme: const DividerThemeData(color: Palette.line, thickness: 1, space: 1),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Palette.paper,
        indicatorColor: Palette.indigo.withValues(alpha: 0.10),
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? Palette.indigoDeep
                : Palette.inkSoft,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? Palette.indigoDeep
                : Palette.inkSoft,
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: Palette.ink,
        contentTextStyle: const TextStyle(color: Palette.paper),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Palette.radiusSm),
        ),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(Palette.radiusSm),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Slightly tighter than Material's defaults, which are set for a denser
  /// information display than a clinic app wants.
  static TextTheme _scale(TextTheme base) {
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: Palette.ink,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: Palette.ink,
      ),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Palette.ink),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Palette.ink),
      bodyLarge: base.bodyLarge?.copyWith(color: Palette.ink, height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(color: Palette.inkSoft, height: 1.55),
      bodySmall: base.bodySmall?.copyWith(color: Palette.inkSoft, height: 1.5),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  /// Nastaliq needs the extra leading — its letters descend within the word,
  /// and at Latin line heights the tails of one line touch the heads of the
  /// next. 1.9 is the smallest value at which that stops at body sizes.
  static TextTheme _urduScale(TextTheme base) {
    final latin = _scale(base);
    return latin.copyWith(
      headlineLarge: latin.headlineLarge?.copyWith(height: 1.8, letterSpacing: 0),
      headlineMedium: latin.headlineMedium?.copyWith(height: 1.8, letterSpacing: 0),
      titleLarge: latin.titleLarge?.copyWith(height: 1.8),
      titleMedium: latin.titleMedium?.copyWith(height: 1.85),
      bodyLarge: latin.bodyLarge?.copyWith(height: 1.9),
      bodyMedium: latin.bodyMedium?.copyWith(height: 1.95),
      bodySmall: latin.bodySmall?.copyWith(height: 1.9),
    );
  }
}
