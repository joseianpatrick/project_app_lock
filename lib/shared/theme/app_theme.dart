import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final ThemeData lightTheme = _buildTheme(
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF9F9FC),
  surface: const Color(0xFFFFFBFF),
  surfaceContainerHighest: const Color(0xFFF5F1F8),
  cardColor: Colors.white,
  borderColor: const Color(0xFFE8E8F0),
  inputBorderColor: const Color(0xFFE5E5ED),
);

final ThemeData darkTheme = _buildTheme(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF121218),
  surface: const Color(0xFF191922),
  surfaceContainerHighest: const Color(0xFF292936),
  cardColor: const Color(0xFF1D1D27),
  borderColor: const Color(0xFF393946),
  inputBorderColor: const Color(0xFF41414F),
);

ThemeData _buildTheme({
  required Brightness brightness,
  required Color scaffoldBackgroundColor,
  required Color surface,
  required Color surfaceContainerHighest,
  required Color cardColor,
  required Color borderColor,
  required Color inputBorderColor,
}) {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF565886),
        brightness: brightness,
      ).copyWith(
        primary: const Color(0xFF8586C7),
        primaryContainer: brightness == Brightness.light
            ? const Color(0xFFF0EDFB)
            : const Color(0xFF393A68),
        onPrimaryContainer: brightness == Brightness.light
            ? const Color(0xFF393A68)
            : const Color(0xFFE5E4FF),
        surface: surface,
        surfaceContainerHighest: surfaceContainerHighest,
      );

  return ThemeData(
    colorScheme: colorScheme,
    textTheme: GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ),
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: borderColor),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColor,
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: inputBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: inputBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    ),
    useMaterial3: true,
  );
}

class AppThemeScope extends InheritedWidget {
  const AppThemeScope({
    required this.isDark,
    required this.onToggle,
    required super.child,
    super.key,
  });

  final bool isDark;
  final VoidCallback onToggle;

  static AppThemeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppThemeScope>();

  @override
  bool updateShouldNotify(AppThemeScope oldWidget) =>
      isDark != oldWidget.isDark || onToggle != oldWidget.onToggle;
}
