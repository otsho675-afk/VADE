import 'package:flutter/material.dart';

/// Unified VADESİ design system: deep ink, calm teal and high-contrast surfaces.
class AppTheme {
  static const ink = Color(0xFF102C3C);
  static const navy = Color(0xFF14384B);
  static const teal = Color(0xFF0F8C87);
  static const darkBg = Color(0xFF091923);
  static const darkCard = Color(0xFF142B38);

  static ThemeData light() => _theme(
    Brightness.light, const Color(0xFF116D70),
    const Color(0xFFF4F7F8), Colors.white,
  );

  static ThemeData dark() => _theme(
    Brightness.dark, const Color(0xFF7FD5CB),
    darkBg, darkCard,
  );

  static ThemeData _theme(
      Brightness mode, Color primary, Color background, Color card) {
    final dark = mode == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: mode,
      primary: primary,
      secondary: dark ? const Color(0xFF8FB6DC) : const Color(0xFF426A91),
      tertiary: dark ? const Color(0xFFC7C08A) : const Color(0xFF8C7246),
      surface: card,
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFAC4242),
    );
    final border = dark ? const Color(0xFF294553) : const Color(0xFFE1E9EC);
    final titleColor = dark ? const Color(0xFFF1F7F8) : ink;
    final secondaryText = dark ? const Color(0xFFB0C6D0) : const Color(0xFF576F7C);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22), side: BorderSide(color: border));
    return ThemeData(
      useMaterial3: true,
      brightness: mode,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background, foregroundColor: titleColor,
        elevation: 0, centerTitle: false, surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 19, fontWeight: FontWeight.w800, color: titleColor,
        ),
      ),
      cardTheme: CardThemeData(
        color: card, elevation: 0, surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero, shape: shape,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1E3947) : const Color(0xFFFAFCFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: primary, width: 1.8)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: scheme.error)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52), elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      )),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      )),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: border),
        backgroundColor: card,
        selectedColor: primary.withValues(alpha: .16),
        labelStyle: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: dark ? .23 : .12),
        height: 76,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          color: states.contains(WidgetState.selected) ? primary : secondaryText,
          fontSize: 11, fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w800 : FontWeight.w600,
        )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: card, indicatorColor: primary.withValues(alpha: .14),
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: secondaryText),
        selectedLabelTextStyle: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w800),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card, surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFF315160) : ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textTheme: TextTheme(
        displaySmall: TextStyle(color: titleColor, fontSize: 37, fontWeight: FontWeight.w900, letterSpacing: -1.5),
        headlineMedium: TextStyle(color: titleColor, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -.8),
        headlineSmall: TextStyle(color: titleColor, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.5),
        titleLarge: TextStyle(color: titleColor, fontSize: 19, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: titleColor, fontSize: 15, height: 1.45),
        bodyMedium: TextStyle(color: secondaryText, fontSize: 14, height: 1.4),
      ),
    );
  }
}
