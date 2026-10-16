import 'package:flutter/material.dart';

/// VADESİ's shared palette and spacing language for compact iPhone screens.
class AppTheme {
  static const ink = Color(0xFF17313D);
  static const navy = Color(0xFF173B47);
  static const teal = Color(0xFF087F77);
  static const darkBg = Color(0xFF0C1C23);
  static const darkCard = Color(0xFF172D36);

  static ThemeData light() => _theme(
    Brightness.light, const Color(0xFF08776F),
    const Color(0xFFF3F7F5), Colors.white,
  );

  static ThemeData dark() => _theme(
    Brightness.dark, const Color(0xFF8BE0D1),
    darkBg, darkCard,
  );

  static ThemeData _theme(
      Brightness mode, Color primary, Color background, Color card) {
    final dark = mode == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: mode,
      primary: primary,
      secondary: dark ? const Color(0xFFA9CCE5) : const Color(0xFF426D83),
      tertiary: dark ? const Color(0xFFF4CA8A) : const Color(0xFF9C6832),
      surface: card,
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFAC4242),
    );
    final border = dark ? const Color(0xFF2A4550) : const Color(0xFFDFE9E6);
    final titleColor = dark ? const Color(0xFFF2F8F6) : ink;
    final secondaryText = dark ? const Color(0xFFB7CBCB) : const Color(0xFF60777C);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24), side: BorderSide(color: border));
    return ThemeData(
      useMaterial3: true,
      brightness: mode,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: background, foregroundColor: titleColor,
        elevation: 0, centerTitle: false, surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
        fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.3,
        color: titleColor,
        ),
      ),
      cardTheme: CardThemeData(
        color: card, elevation: 0, surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero, shape: shape,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF203943) : const Color(0xFFFBFDFC),
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
        indicatorColor: primary.withValues(alpha: dark ? .24 : .11),
        height: 72,
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
        displaySmall: TextStyle(color: titleColor, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1.8),
        headlineMedium: TextStyle(color: titleColor, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1),
        headlineSmall: TextStyle(color: titleColor, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.5),
        titleLarge: TextStyle(color: titleColor, fontSize: 19, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: titleColor, fontSize: 15, height: 1.45),
        bodyMedium: TextStyle(color: secondaryText, fontSize: 14, height: 1.4),
      ),
    );
  }
}
