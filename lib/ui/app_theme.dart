import 'package:flutter/material.dart';

class AppTheme {
  static const ink = Color(0xFF182D2B);
  static const navy = Color(0xFF13695C);
  static const darkBg = Color(0xFF0D1B19);
  static const darkCard = Color(0xFF162A26);

  static ThemeData light() => _theme(
    Brightness.light,
    const Color(0xFF13695C),
    const Color(0xFFF3F6F2),
    Colors.white,
  );

  static ThemeData dark() => _theme(
    Brightness.dark,
    const Color(0xFF8ED9BD),
    darkBg,
    darkCard,
  );

  static ThemeData _theme(Brightness mode, Color primary, Color background, Color card) {
    final dark = mode == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: mode,
      primary: primary,
      surface: card,
      error: dark ? const Color(0xFFFFA69D) : const Color(0xFFAD3C40),
    );
    final border = dark ? const Color(0xFF304B43) : const Color(0xFFE3E8EE);
    final titleColor = dark ? const Color(0xFFF5F7F9) : ink;
    return ThemeData(
      useMaterial3: true,
      brightness: mode,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: titleColor,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        isDense: false,
        filled: true,
        fillColor: dark ? const Color(0xFF203A32) : const Color(0xFFF7F9F5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.error)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: .13),
        height: 72,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: card,
        indicatorColor: primary.withValues(alpha: .13),
        selectedIconTheme: IconThemeData(color: primary),
        selectedLabelTextStyle: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w700),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: card, surfaceTintColor: Colors.transparent),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFF304B43) : const Color(0xFF263C50),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(color: titleColor, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.6),
        headlineSmall: TextStyle(color: titleColor, fontSize: 21, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: titleColor, fontSize: 15),
        bodyMedium: TextStyle(color: dark ? const Color(0xFFD3DBE4) : const Color(0xFF485869), fontSize: 14),
      ),
    );
  }
}
