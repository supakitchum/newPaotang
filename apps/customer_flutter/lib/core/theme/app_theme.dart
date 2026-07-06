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
      onSurface: tokens.textColor ?? baseScheme.onSurface,
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
    final rootTokens = _mergeMaps([
      json['tokens'],
      json['design_tokens'],
      json['designTokens'],
      json['theme_tokens'],
      json['themeTokens'],
    ]);
    final modes = _mergeMaps([
      json['modes'],
      json['themes'],
      rootTokens['modes'],
      rootTokens['themes'],
    ]);
    final tokens = _mergeMaps([
      rootTokens,
      json['light'],
      json['lightMode'],
      json['default'],
      rootTokens['light'],
      rootTokens['lightMode'],
      rootTokens['default'],
      modes['light'],
      modes['default'],
    ]);
    final colors = _mergeMaps([tokens['colors'], json['colors']]);
    final color = _mergeMaps([tokens['color'], json['color']]);
    final palette = _mergeMaps([tokens['palette'], json['palette']]);
    final brand = _mergeMaps([tokens['brand'], json['brand']]);
    final semantic = _mergeMaps([tokens['semantic'], json['semantic']]);
    final typography = _mergeMaps([
      tokens['typography'],
      tokens['type'],
      tokens['types'],
      json['typography'],
      json['type'],
      json['types'],
    ]);
    final font = _mergeMaps([
      tokens['font'],
      tokens['fonts'],
      json['font'],
      json['fonts'],
    ]);
    return AppThemeTokens(
      primaryColor: _parseColor(
        _firstColorValue([
          json['primary_color'],
          json['primaryColor'],
          json['primary_colour'],
          json['primaryColour'],
          json['primary'],
          json['brand_primary'],
          json['brandPrimary'],
          tokens['primary_color'],
          tokens['primaryColor'],
          tokens['primary'],
          tokens['brand_primary'],
          tokens['brandPrimary'],
          colors['primary_color'],
          colors['primaryColor'],
          colors['primary'],
          colors['brand'],
          color['primary'],
          palette['primary'],
          palette['brand'],
          brand['primary_color'],
          brand['primaryColor'],
          brand['primary'],
          brand['main'],
          brand['base'],
        ]),
      ),
      secondaryColor: _parseColor(
        _firstColorValue([
          json['secondary_color'],
          json['secondaryColor'],
          json['secondary_colour'],
          json['secondaryColour'],
          json['secondary'],
          json['brand_secondary'],
          json['brandSecondary'],
          tokens['secondary_color'],
          tokens['secondaryColor'],
          tokens['secondary'],
          tokens['brand_secondary'],
          tokens['brandSecondary'],
          colors['secondary_color'],
          colors['secondaryColor'],
          colors['secondary'],
          color['secondary'],
          palette['secondary'],
          brand['secondary_color'],
          brand['secondaryColor'],
          brand['secondary'],
        ]),
      ),
      accentColor: _parseColor(
        _firstColorValue([
          json['accent_color'],
          json['accentColor'],
          json['accent'],
          json['tertiary_color'],
          json['tertiaryColor'],
          json['button_color'],
          json['buttonColor'],
          json['cta_color'],
          json['ctaColor'],
          tokens['accent_color'],
          tokens['accentColor'],
          tokens['accent'],
          tokens['tertiary_color'],
          tokens['tertiaryColor'],
          tokens['button_color'],
          tokens['buttonColor'],
          tokens['cta_color'],
          tokens['ctaColor'],
          colors['accent_color'],
          colors['accentColor'],
          colors['accent'],
          colors['tertiary'],
          color['accent'],
          color['tertiary'],
          palette['accent'],
          palette['tertiary'],
          semantic['accent'],
          semantic['cta'],
        ]),
      ),
      backgroundColor: _parseColor(
        _firstColorValue([
          json['background_color'],
          json['backgroundColor'],
          json['background_colour'],
          json['backgroundColour'],
          json['background'],
          json['page_background_color'],
          json['pageBackgroundColor'],
          json['scaffold_background_color'],
          json['scaffoldBackgroundColor'],
          json['surface_color'],
          json['surfaceColor'],
          json['surface'],
          tokens['background_color'],
          tokens['backgroundColor'],
          tokens['background'],
          tokens['page_background_color'],
          tokens['pageBackgroundColor'],
          tokens['scaffold_background_color'],
          tokens['scaffoldBackgroundColor'],
          tokens['surface_color'],
          tokens['surfaceColor'],
          tokens['surface'],
          colors['background_color'],
          colors['backgroundColor'],
          colors['background'],
          colors['surface_color'],
          colors['surfaceColor'],
          colors['surface'],
          color['background'],
          color['surface'],
          palette['background'],
          palette['surface'],
          semantic['background'],
          semantic['surface'],
        ]),
      ),
      textColor: _parseColor(
        _firstColorValue([
          json['text_color'],
          json['textColor'],
          json['foreground_color'],
          json['foregroundColor'],
          json['text'],
          json['on_surface'],
          json['onSurface'],
          json['on_background'],
          json['onBackground'],
          tokens['text_color'],
          tokens['textColor'],
          tokens['foreground_color'],
          tokens['foregroundColor'],
          tokens['text'],
          tokens['on_surface'],
          tokens['onSurface'],
          tokens['on_background'],
          tokens['onBackground'],
          colors['text_color'],
          colors['textColor'],
          colors['text'],
          colors['foreground'],
          colors['content'],
          colors['on_surface'],
          colors['onSurface'],
          colors['on_background'],
          colors['onBackground'],
          color['text'],
          color['foreground'],
          color['content'],
          palette['text'],
          palette['foreground'],
          semantic['text'],
          semantic['foreground'],
          semantic['content'],
          semantic['on_surface'],
          semantic['onSurface'],
        ]),
      ),
      fontFamily: _firstFontFamily([
            json['font_family'],
            json['fontFamily'],
            json['font'],
            json['fonts'],
            json['font_families'],
            json['fontFamilies'],
            tokens['font_family'],
            tokens['fontFamily'],
            tokens['font'],
            tokens['fonts'],
            tokens['font_families'],
            tokens['fontFamilies'],
            typography['font_family'],
            typography['fontFamily'],
            typography['family'],
            typography['name'],
            typography['primary'],
            typography['body'],
            typography['base'],
            typography['default'],
            typography['sans'],
            typography['sans_serif'],
            typography['sansSerif'],
            typography['font'],
            typography['fonts'],
            typography['font_families'],
            typography['fontFamilies'],
            font['font_family'],
            font['fontFamily'],
            font['family'],
            font['name'],
            font['primary'],
            font['body'],
            font['base'],
            font['default'],
            font['sans'],
            font['sans_serif'],
            font['sansSerif'],
            font['families'],
            font['font_families'],
            font['fontFamilies'],
            typography,
            font,
          ]) ??
          fallback.fontFamily,
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
    final rgb = _parseRgbColor(value);
    if (rgb != null) return rgb;
    final hsl = _parseHslColor(value);
    if (hsl != null) return hsl;

    if (value.startsWith('#')) {
      return _parseHexColor(value.substring(1), alphaLast: true);
    }

    if (value.toLowerCase().startsWith('0x')) {
      return _parseHexColor(value.substring(2), alphaLast: false);
    }

    return _parseHexColor(value, alphaLast: false);
  }

  static Color? _parseHexColor(String raw, {required bool alphaLast}) {
    final hex = raw.trim();
    if (hex.isEmpty || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) return null;

    final expanded = switch (hex.length) {
      3 => 'FF${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}',
      4 when alphaLast =>
        '${hex[3]}${hex[3]}${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}',
      6 => 'FF$hex',
      8 when alphaLast => '${hex.substring(6, 8)}${hex.substring(0, 6)}',
      8 => hex,
      _ => null,
    };
    if (expanded == null) return null;

    final parsed = int.tryParse(expanded, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  static Color? _parseRgbColor(String value) {
    final match = RegExp(
      r'^rgba?\((.+)\)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;

    final rawChannels = match.group(1)?.trim() ?? '';
    final slashParts = rawChannels.split('/');
    final colorPart = slashParts.first.trim();
    final alphaPart = slashParts.length > 1 ? slashParts[1].trim() : null;
    final channels = colorPart.contains(',')
        ? colorPart.split(',').map((value) => value.trim()).toList()
        : colorPart
            .split(RegExp(r'\s+'))
            .where((value) => value.isNotEmpty)
            .toList();

    if (channels.length < 3) return null;
    final red = _parseRgbChannel(channels[0]);
    final green = _parseRgbChannel(channels[1]);
    final blue = _parseRgbChannel(channels[2]);
    final alpha = _parseAlphaChannel(
      alphaPart ?? (channels.length > 3 ? channels[3] : null),
    );
    if (red == null || green == null || blue == null || alpha == null) {
      return null;
    }

    return Color.fromARGB(alpha, red, green, blue);
  }

  static Color? _parseHslColor(String value) {
    final match = RegExp(
      r'^hsla?\((.+)\)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;

    final rawChannels = match.group(1)?.trim() ?? '';
    final slashParts = rawChannels.split('/');
    final colorPart = slashParts.first.trim();
    final alphaPart = slashParts.length > 1 ? slashParts[1].trim() : null;
    final channels = colorPart.contains(',')
        ? colorPart.split(',').map((value) => value.trim()).toList()
        : colorPart
            .split(RegExp(r'\s+'))
            .where((value) => value.isNotEmpty)
            .toList();

    if (channels.length < 3) return null;
    final hue = _parseHueChannel(channels[0]);
    final saturation = _parsePercentChannel(channels[1]);
    final lightness = _parsePercentChannel(channels[2]);
    final alpha = _parseAlphaChannel(
      alphaPart ?? (channels.length > 3 ? channels[3] : null),
    );
    if (hue == null ||
        saturation == null ||
        lightness == null ||
        alpha == null) {
      return null;
    }

    return HSLColor.fromAHSL(
      alpha / 255,
      hue,
      saturation,
      lightness,
    ).toColor();
  }

  static int? _parseRgbChannel(String raw) {
    final value = raw.trim();
    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) return null;
      return (percent.clamp(0, 100) * 2.55).round();
    }

    final number = double.tryParse(value);
    if (number == null) return null;
    return number.round().clamp(0, 255).toInt();
  }

  static int? _parseAlphaChannel(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return 255;
    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) return null;
      return (percent.clamp(0, 100) * 2.55).round();
    }

    final number = double.tryParse(value);
    if (number == null) return null;
    if (number <= 1) return (number.clamp(0, 1) * 255).round();
    return number.round().clamp(0, 255).toInt();
  }

  static double? _parseHueChannel(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.endsWith('deg')) {
      return _normalizeHue(value.substring(0, value.length - 3));
    }
    if (value.endsWith('turn')) {
      final turns = double.tryParse(value.substring(0, value.length - 4));
      if (turns == null) return null;
      return (turns * 360) % 360;
    }
    if (value.endsWith('rad')) {
      final radians = double.tryParse(value.substring(0, value.length - 3));
      if (radians == null) return null;
      return (radians * 180 / 3.141592653589793) % 360;
    }
    return _normalizeHue(value);
  }

  static double? _normalizeHue(String raw) {
    final number = double.tryParse(raw.trim());
    if (number == null) return null;
    final normalized = number % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  static double? _parsePercentChannel(String raw) {
    final value = raw.trim();
    if (!value.endsWith('%')) return null;
    final percent = double.tryParse(value.substring(0, value.length - 1));
    if (percent == null) return null;
    return percent.clamp(0, 100) / 100;
  }

  static Map<String, dynamic> _mergeMaps(Iterable<Object?> values) {
    final merged = <String, dynamic>{};
    for (final value in values) {
      final map = _asMap(value);
      if (map.isNotEmpty) _deepMergeConfigMap(merged, map);
    }
    return merged;
  }

  static void _deepMergeConfigMap(
    Map<String, dynamic> target,
    Map<String, dynamic> source,
  ) {
    for (final entry in source.entries) {
      final value = entry.value;
      if (_isBlankConfigValue(value)) continue;

      final current = target[entry.key];
      if (current is Map && value is Map) {
        final nested = Map<String, dynamic>.from(current);
        _deepMergeConfigMap(nested, Map<String, dynamic>.from(value));
        target[entry.key] = nested;
        continue;
      }

      target[entry.key] = value;
    }
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static String? _firstColorValue(Iterable<Object?> values) {
    for (final value in values) {
      final stringValue = _colorValue(value);
      if (stringValue != null && stringValue.isNotEmpty) return stringValue;
    }
    return null;
  }

  static String? _colorValue(Object? value) {
    if (value == null) return null;
    if (value is String) return value.trim();
    if (value is Iterable) return _firstColorValue(value);
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return _firstColorValue([
        map['value'],
        map['color'],
        map['colour'],
        map['hex'],
        map['hex_value'],
        map['hexValue'],
        map['css'],
        map['css_value'],
        map['cssValue'],
        map['token'],
        map['main'],
        map['base'],
        map['default'],
        map['light'],
      ]);
    }
    return value.toString().trim();
  }

  static String? _firstFontFamily(Iterable<Object?> values) {
    for (final value in values) {
      final stringValue = _fontFamilyValue(value);
      if (stringValue != null && stringValue.isNotEmpty) return stringValue;
    }
    return null;
  }

  static String? _fontFamilyValue(Object? value) {
    if (value == null) return null;
    if (value is String) return value.trim();
    if (value is Iterable) return _firstFontFamily(value);
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return _firstFontFamily([
        map['font_family'],
        map['fontFamily'],
        map['family'],
        map['font_family_name'],
        map['fontFamilyName'],
        map['name'],
        map['value'],
        map['primary'],
        map['body'],
        map['base'],
        map['default'],
        map['sans'],
        map['sans_serif'],
        map['sansSerif'],
        map['display'],
        map['heading'],
        map['regular'],
        map['main'],
        map['font'],
        map['fonts'],
        map['families'],
        map['font_families'],
        map['fontFamilies'],
      ]);
    }
    return value.toString().trim();
  }

  static bool _isBlankConfigValue(Object? value) {
    if (value == null) return true;
    return value is String && value.trim().isEmpty;
  }
}
