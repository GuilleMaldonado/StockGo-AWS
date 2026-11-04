import 'package:flutter/material.dart';

import '../widgets/stockgo_background.dart';

abstract final class StockGoTheme {
  static const navy = Color(0xFF123B56);
  static const teal = Color(0xFF0073B1);
  static const blue = Color(0xFF0284C7);
  static const sky = Color(0xFF38BDF8);
  static const green = Color(0xFF07845C);
  static const yellow = Color(0xFFFFC857);
  static const ink = Color(0xFF101820);
  static const background = Color(0xFFF2F8FC);
  static const muted = Color(0xFF547084);
  static const line = Color(0xFFD9EAF4);

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: teal,
          brightness: Brightness.light,
        ).copyWith(
          primary: teal,
          secondary: blue,
          tertiary: green,
          surface: Colors.white,
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: StockGoPageTransition(),
          TargetPlatform.iOS: StockGoPageTransition(),
          TargetPlatform.windows: StockGoPageTransition(),
          TargetPlatform.macOS: StockGoPageTransition(),
          TargetPlatform.linux: StockGoPageTransition(),
        },
      ),
      textTheme: base.textTheme
          .apply(bodyColor: navy, displayColor: navy)
          .copyWith(
            headlineLarge: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: navy,
            ),
            headlineMedium: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
              color: navy,
            ),
            titleLarge: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFEAF7FF),
        foregroundColor: navy,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        toolbarHeight: 68,
        shape: Border(bottom: BorderSide(color: line)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: navy.withValues(alpha: .07),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        labelStyle: const TextStyle(color: muted),
        prefixIconColor: teal,
        suffixIconColor: muted,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: teal, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shadowColor: teal.withValues(alpha: .25),
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: line, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(10)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? Colors.transparent
                : teal.withValues(
                    alpha:
                        states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.focused)
                        ? .14
                        : .055,
                  ),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFD9F2FF),
        side: const BorderSide(color: line),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: navy,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: teal,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: navy,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: teal,
        linearMinHeight: 3,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 1,
        hoverElevation: 1,
        highlightElevation: 0,
        backgroundColor: teal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
    );
  }
}
