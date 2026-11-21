import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SideBColors {
  SideBColors._();
  static const graphite = Color(0xFF292A27);
  static const ivory = Color(0xFFEAE3D6);
  static const olive = Color(0xFF858C77);
  static const terracotta = Color(0xFFA96F58);
  static const controlBorder = Color(0xFF8B8477);
  static const accent = Color(0xFF85513E);
  static const paper = Color(0xFFF4F0E8);
  static const muted = Color(0xFF625F56);
  static const border = Color(0x2E292A27);
  static const error = Color(0xFFB5473F);
  static const success = Color(0xFF4D7057);
  static const panel = Color(0xFFE1DBCF);
  static const skeleton = panel;
}

class SideBTheme {
  SideBTheme._();
  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final canvas = dark ? const Color(0xFF222320) : SideBColors.ivory;
    final paper = dark ? const Color(0xFF30312D) : SideBColors.paper;
    final ink = dark ? SideBColors.ivory : SideBColors.graphite;
    final accent = dark ? const Color(0xFFE1A38A) : SideBColors.accent;
    final muted = dark ? const Color(0xFFC3BBAE) : SideBColors.muted;
    final panel = dark ? const Color(0xFF3B3D35) : SideBColors.panel;
    final border = dark ? const Color(0x40EAE3D6) : SideBColors.border;
    final outline = dark ? const Color(0xFF9C968A) : SideBColors.controlBorder;
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: ink,
        onPrimary: dark ? canvas : paper,
        primaryContainer: panel,
        onPrimaryContainer: ink,
        secondary: accent,
        onSecondary: dark ? canvas : paper,
        secondaryContainer: panel,
        onSecondaryContainer: ink,
        surface: canvas,
        surfaceDim: panel,
        surfaceBright: canvas,
        surfaceContainerLowest: paper,
        surfaceContainerLow: paper,
        surfaceContainer: canvas,
        surfaceContainerHigh: panel,
        surfaceContainerHighest: panel,
        surfaceTint: Colors.transparent,
        onSurface: ink,
        onSurfaceVariant: muted,
        outline: outline,
        outlineVariant: border,
        error: dark ? const Color(0xFFFFABA3) : SideBColors.error,
        onError: dark ? const Color(0xFF451613) : Colors.white,
      ),
      fontFamily: 'SpaceGrotesk',
      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontFamily: 'InstrumentSerif',
          fontSize: 44,
          height: 1,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'InstrumentSerif',
          fontSize: 32,
          height: 1,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 18,
          height: 1.15,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 16,
          height: 1.5,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 14,
          height: 1.45,
          color: muted,
        ),
        labelMedium: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.25,
          color: muted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: border)),
        titleTextStyle: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ink,
        foregroundColor: canvas,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorMaxLines: 3,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        actionTextColor: dark ? canvas : paper,
        contentTextStyle: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 14,
          color: dark ? canvas : paper,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SideBColors.olive,
        strokeWidth: 2.5,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: SideBColors.olive,
        selectionColor: Color(0x44858C77),
        selectionHandleColor: SideBColors.olive,
      ),
      dividerTheme: DividerThemeData(color: border, space: 1),
    );
  }
}
