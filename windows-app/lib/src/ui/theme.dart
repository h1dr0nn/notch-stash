import 'package:flutter/material.dart';

/// Dark look close to the Mac shelf: near-black panel, soft secondary text, blue accent.
class ShelfColors {
  ShelfColors._();

  static const background = Color(0xFF1C1C1E);
  static const surface = Color(0xFF2C2C2E);
  static const tile = Color(0x14FFFFFF);
  static const tileHover = Color(0x24FFFFFF);
  static const primaryText = Color(0xFFF2F2F7);
  static const secondaryText = Color(0xFF9A9AA0);
  static const separator = Color(0x22FFFFFF);
  static const accent = Color(0xFF0A84FF);
  static const success = Color(0xFF30D158);
  static const danger = Color(0xFFFF453A);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: ShelfColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: ShelfColors.accent,
    onPrimary: Colors.white,
    surface: ShelfColors.background,
    onSurface: ShelfColors.primaryText,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: ShelfColors.background,
    fontFamily: 'Segoe UI',
    visualDensity: VisualDensity.compact,
    splashFactory: NoSplash.splashFactory,
    dividerColor: ShelfColors.separator,
    tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 600)),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ShelfColors.secondaryText,
        textStyle: const TextStyle(fontSize: 12),
        minimumSize: const Size(0, 26),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : ShelfColors.secondaryText,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? ShelfColors.accent : ShelfColors.surface,
      ),
    ),
  );
}
