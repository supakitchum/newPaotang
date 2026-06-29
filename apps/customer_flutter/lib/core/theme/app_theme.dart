import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light({AppThemeTokens tokens = AppThemeTokens.fallback}) {
    final seed = tokens.primaryColor ?? AppThemeTokens.fallback.primaryColor!;
    final background =
        tokens.backgroundColor ?? AppThemeTokens.fallback.backgroundColor!;
    final baseScheme = ColorScheme.fromSeed(seedColor: seed);
    final colorScheme = baseScheme.copyWith(
      primary: seed,
      secondary: tokens.secondaryColor ?? baseScheme.secondary,
      tertiary: tokens.accentColor ?? baseScheme.tertiary,
      surface: background,
    );
    final textColor = tokens.textColor;
    final textTheme = textColor == null
        ? null
        : ThemeData.light().textTheme.apply(
              bodyColor: textColor,
              displayColor: textColor,
            );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: tokens.fontFamily.trim().isEmpty
          ? AppThemeTokens.fallback.fontFamily
          : tokens.fontFamily.trim(),
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        foregroundColor: Colors.white,
        titleTextStyle: ThemeData.light().textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
    );
  }
}

class AppThemeTokens {
  const AppThemeTokens({
    this.primaryColor,
    this.secondaryColor,
    this.accentColor,
    this.backgroundColor,
    this.textColor,
    this.fontFamily = 'Roboto',
  });

  factory AppThemeTokens.fromJson(Map<String, dynamic> json) {
    return AppThemeTokens(
      primaryColor: _parseColor(json['primary_color']?.toString()),
      secondaryColor: _parseColor(json['secondary_color']?.toString()),
      accentColor: _parseColor(json['accent_color']?.toString()),
      backgroundColor: _parseColor(json['background_color']?.toString()),
      textColor: _parseColor(json['text_color']?.toString()),
      fontFamily: json['font_family']?.toString() ?? fallback.fontFamily,
    );
  }

  static const fallback = AppThemeTokens(
    primaryColor: Color(0xFF0D7FF2),
    backgroundColor: Color(0xFFF4F7FB),
    fontFamily: 'Roboto',
  );

  final Color? primaryColor;
  final Color? secondaryColor;
  final Color? accentColor;
  final Color? backgroundColor;
  final Color? textColor;
  final String fontFamily;

  bool get hasRuntimeColors =>
      primaryColor != null ||
      secondaryColor != null ||
      accentColor != null ||
      backgroundColor != null ||
      textColor != null;

  static Color? _parseColor(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    var hex = value;
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.toLowerCase().startsWith('0x')) hex = hex.substring(2);
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}
