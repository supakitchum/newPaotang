import 'package:flutter/material.dart';

class AppTheme {
  static const appBlue = Color(0xFF087FF0);
  static const appBlueDark = Color(0xFF0067D9);
  static const appSky = Color(0xFF19B8EF);
  static const appYellow = Color(0xFFFFD10B);
  static const appInk = Color(0xFF242833);
  static const appMuted = Color(0xFF8A8F98);
  static const appBorder = Color(0xFFE8EBEF);
  static const appSoft = Color(0xFFF5F7FB);
  static const appSheet = Color(0xFFFFFFFF);
  static const appHeroStart = Color(0xFF158FF6);
  static const appHeroEnd = Color(0xFF0564D1);
  static const appActionStart = Color(0xFF149AF9);
  static const appActionEnd = Color(0xFF0064D5);
  static const appDisabledAction = Color(0xFFC6D3E3);
  static const appOutlinePillText = Color(0xFF075EC9);
  static const appOutlinePillBorder = Color(0xFF0B69DC);
  static const appOutlinePillDisabledBorder = Color(0xFFCBD4DF);
  static const appOutlinePillDisabledText = Color(0xFF8A8F98);
  static const appOutlinePillDisabledFill = Color(0xFFF2F4F7);
  static const appFilterPillFill = Color(0xFFF7F7F7);
  static const appFilterPillText = Color(0xFF2D3036);
  static const appFilterPillActiveBorder = Color(0xFF086BDD);
  static const appBlueLink = Color(0xFF0068D8);
  static const appPaymentCountBlue = Color(0xFF006FE8);
  static const appGreenPillStart = Color(0xFF77C827);
  static const appGreenPillEnd = Color(0xFF55B20E);
  static const appLotteryNumberFill = Color(0xFFFFF9DF);
  static const appCheckoutWalletBorder = Color(0xFF267FF2);
  static const appCheckoutWalletNoteFill = Color(0xFFDCEEFF);
  static const appCheckoutWalletNoteText = Color(0xFF065FCA);
  static const appCheckoutWalletMark = Color(0xFF1E8BC2);
  static const appSuccessGradientEnd = Color(0xFF20BCF2);
  static const appSuccessRadialBlue = Color(0xFF005BC6);
  static const appSuccessCheck = Color(0xFF71BF18);
  static const appLotterySix = Color(0xFF0C75D4);
  static const appBottomNavActive = Color(0xFF0768D5);
  static const appBottomNavInactive = Color(0xFF8C8F93);
  static const appBottomNavActiveFill = Color(0xFFEEF8FF);
  static const appBottomNavShadow = Color(0xFF14233A);
  static const appWalletSheet = Color(0xFFF4F6F8);
  static const appWalletGradientEnd = Color(0xFF12A077);
  static const appActivityActionFill = Color(0xFFE8F4FF);
  static const appActivityActionText = Color(0xFF0875DF);
  static const appActivityFallbackStart = Color(0xFFE8F6FF);
  static const appActivityFallbackEnd = Color(0xFFF4FBFF);
  static const appActivityFallbackIcon = Color(0xFF0B7FE8);
  static const appPinAction = Color(0xFF0D7FE8);
  static const appPinActionFill = Color(0xFFE8F3FF);
  static const appPinGradientStart = Color(0xFF14A7FF);
  static const appPinGradientEnd = Color(0xFF0062D9);
  static const appTicketTabStart = Color(0xFF1495F5);
  static const appTicketTabEnd = Color(0xFF0066D6);
  static const appTicketCountFill = Color(0xFFEEF6FF);
  static const appTicketCountText = Color(0xFF0B63C7);
  static const appClaimChevron = Color(0xFF3B9CFF);
  static const appMaintenanceGradientEnd = Color(0xFF174A8B);
  static const appSuspendedGradientStart = Color(0xFF0D8FFF);
  static const appSuspendedGradientMid = Color(0xFF0C69D8);
  static const appSuspendedGradientEnd = Color(0xFF0AA58F);
  static const appSuspendedRadialAccent = Color(0xDBFFD60A);
  static const appCountdownGradientMid = Color(0xFF0A66C8);
  static const appCountdownGradientEnd = Color(0xFF163970);
  static const appSystemActionStart = Color(0xFF168CF2);
  static const appSystemActionEnd = Color(0xFF0A64D8);

  static Color primaryActionStart(Color primary) {
    if (primary == appBlue) return appActionStart;
    return _shiftHsl(
      primary,
      saturationDelta: 0.04,
      lightnessDelta: 0.06,
      minLightness: 0.48,
      maxLightness: 0.62,
    );
  }

  static Color primaryActionEnd(Color primary) {
    if (primary == appBlue) return appActionEnd;
    return _shiftHsl(
      primary,
      saturationDelta: 0.04,
      lightnessDelta: -0.09,
      minLightness: 0.34,
      maxLightness: 0.48,
    );
  }

  static Color primaryOutlineText(Color primary) {
    if (primary == appBlue) return appOutlinePillText;
    return primaryActionEnd(primary);
  }

  static Color primaryOutlineBorder(Color primary) {
    if (primary == appBlue) return appOutlinePillBorder;
    return primary;
  }

  static Color primaryLink(Color primary) {
    if (primary == appBlue) return appBlueLink;
    return primaryActionEnd(primary);
  }

  static Color primaryFilterBorder(Color primary) {
    if (primary == appBlue) return appFilterPillActiveBorder;
    return primary;
  }

  static Color primaryPaymentCount(Color primary) {
    if (primary == appBlue) return appPaymentCountBlue;
    return primaryActionEnd(primary);
  }

  static Color checkoutWalletBorder(Color primary) {
    if (primary == appBlue) return appCheckoutWalletBorder;
    return primary;
  }

  static Color checkoutWalletMark(Color primary, Color secondary) {
    if (primary == appBlue && secondary == appSky) {
      return appCheckoutWalletMark;
    }
    return Color.lerp(primary, secondary, 0.34) ?? primary;
  }

  static Color checkoutWalletNoteFill(Color primary) {
    if (primary == appBlue) return appCheckoutWalletNoteFill;
    return Color.lerp(primary, appSheet, 0.84) ?? appSoft;
  }

  static Color checkoutWalletNoteText(Color primary) {
    if (primary == appBlue) return appCheckoutWalletNoteText;
    return primaryActionEnd(primary);
  }

  static Color bottomNavigationActive(Color primary) {
    if (primary == appBlue) return appBottomNavActive;
    return primaryActionEnd(primary);
  }

  static Color bottomNavigationActiveFill(Color primary) {
    if (primary == appBlue) return appBottomNavActiveFill;
    return Color.lerp(primary, appSheet, 0.91) ?? appSoft;
  }

  static Color successGradientEnd(Color primary, Color secondary) {
    if (primary == appBlue && secondary == appSky) {
      return appSuccessGradientEnd;
    }
    return Color.lerp(primary, secondary, 0.72) ?? secondary;
  }

  static Color successRadial(Color primary) {
    if (primary == appBlue) return appSuccessRadialBlue;
    return primaryActionEnd(primary);
  }

  static Color homeActivityFallbackStart(Color primary) {
    if (primary == appBlue) return const Color(0xFF0B84ED);
    return primaryActionStart(primary);
  }

  static Color homeActivityFallbackEnd(Color primary, Color secondary) {
    if (primary == appBlue && secondary == appSky) {
      return const Color(0xFF11A584);
    }
    return Color.lerp(primary, secondary, 0.72) ?? secondary;
  }

  static Color homeNewsFallbackStart(Color primary) {
    if (primary == appBlue) return const Color(0xFF0A87F5);
    return primaryActionStart(primary);
  }

  static Color homeNewsFallbackEnd(Color primary, Color onSurface) {
    if (primary == appBlue) return const Color(0xFF20385F);
    return Color.lerp(primary, onSurface, 0.58) ?? primaryActionEnd(primary);
  }

  static Color newsCardFallbackStart(Color primary) {
    if (primary == appBlue) return const Color(0xFF0B84ED);
    return primaryActionStart(primary);
  }

  static Color newsCardFallbackEnd(Color primary, Color onSurface) {
    if (primary == appBlue) return const Color(0xFF174783);
    return Color.lerp(primary, onSurface, 0.54) ?? primaryActionEnd(primary);
  }

  static Color fallbackSpark(Color accent) {
    if (accent == appYellow) return const Color(0xFFFFD240);
    return accent;
  }

  static Color detailKicker(Color primary) {
    if (primary == appBlue) return const Color(0xFF0875DF);
    return primary;
  }

  static Color activityActionFill(Color primary) {
    if (primary == appBlue) return appActivityActionFill;
    return Color.lerp(primary, appSheet, 0.88) ?? appSoft;
  }

  static Color activityActionText(Color primary) {
    if (primary == appBlue) return appActivityActionText;
    return detailKicker(primary);
  }

  static Color activityFallbackStart(Color primary) {
    if (primary == appBlue) return appActivityFallbackStart;
    return Color.lerp(primary, appSheet, 0.84) ?? primaryContainer(primary);
  }

  static Color activityFallbackEnd(Color primary, Color secondary) {
    if (primary == appBlue && secondary == appSky) {
      return appActivityFallbackEnd;
    }
    return Color.lerp(secondary, appSheet, 0.94) ?? appSoft;
  }

  static Color activityFallbackIcon(Color primary) {
    if (primary == appBlue) return appActivityFallbackIcon;
    return primary;
  }

  static Color pinAction(Color primary) {
    if (primary == appBlue) return appPinAction;
    return primary;
  }

  static Color pinActionFill(Color primary) {
    if (primary == appBlue) return appPinActionFill;
    return Color.lerp(primary, appSheet, 0.88) ?? appSoft;
  }

  static Color pinGradientStart(Color primary) {
    if (primary == appBlue) return appPinGradientStart;
    return primaryActionStart(primary);
  }

  static Color pinGradientEnd(Color primary) {
    if (primary == appBlue) return appPinGradientEnd;
    return primaryActionEnd(primary);
  }

  static Color ticketTabStart(Color primary) {
    if (primary == appBlue) return appTicketTabStart;
    return primaryActionStart(primary);
  }

  static Color ticketTabEnd(Color primary) {
    if (primary == appBlue) return appTicketTabEnd;
    return primaryActionEnd(primary);
  }

  static Color ticketCountFill(Color primary) {
    if (primary == appBlue) return appTicketCountFill;
    return Color.lerp(primary, appSheet, 0.91) ?? appSoft;
  }

  static Color ticketCountText(Color primary) {
    if (primary == appBlue) return appTicketCountText;
    return primaryActionEnd(primary);
  }

  static Color claimChevron(Color primary) {
    if (primary == appBlue) return appClaimChevron;
    return primary;
  }

  static Color lotterySix(Color primary) {
    if (primary == appBlue) return appLotterySix;
    return primaryActionEnd(primary);
  }

  static Color maintenanceGradientEnd(Color primary, Color onSurface) {
    if (primary == appBlue) return appMaintenanceGradientEnd;
    return Color.lerp(primary, onSurface, 0.54) ?? primaryActionEnd(primary);
  }

  static Color suspendedGradientStart(Color primary) {
    if (primary == appBlue) return appSuspendedGradientStart;
    return heroGradientStart(primary);
  }

  static Color suspendedGradientMid(Color primary) {
    if (primary == appBlue) return appSuspendedGradientMid;
    return primaryActionEnd(primary);
  }

  static Color suspendedGradientEnd(Color primary, Color secondary) {
    if (primary == appBlue && secondary == appSky) {
      return appSuspendedGradientEnd;
    }
    return Color.lerp(primary, secondary, 0.72) ?? secondary;
  }

  static Color suspendedRadialAccent(Color accent) {
    if (accent == appYellow) return appSuspendedRadialAccent;
    return accent.withValues(alpha: 0.86);
  }

  static Color countdownGradientMid(Color primary) {
    if (primary == appBlue) return appCountdownGradientMid;
    return primaryActionEnd(primary);
  }

  static Color countdownGradientEnd(Color primary, Color onSurface) {
    if (primary == appBlue) return appCountdownGradientEnd;
    return Color.lerp(primary, onSurface, 0.58) ?? primaryActionEnd(primary);
  }

  static Color systemActionStart(Color primary) {
    if (primary == appBlue) return appSystemActionStart;
    return primaryActionStart(primary);
  }

  static Color systemActionEnd(Color primary) {
    if (primary == appBlue) return appSystemActionEnd;
    return primaryActionEnd(primary);
  }

  static Color primaryContainer(Color primary) {
    return Color.lerp(primary, appSheet, 0.88) ?? appSoft;
  }

  static Color splashGradientMid(Color primary, Color secondary) {
    if (primary == appBlue && secondary == appSky) {
      return const Color(0xFF0C6FE0);
    }
    return Color.lerp(primary, secondary, 0.22) ?? primary;
  }

  static Color splashGradientEnd(Color primary, Color secondary) {
    if (primary == appBlue && secondary == appSky) {
      return const Color(0xFF15AEEA);
    }
    return Color.lerp(primary, secondary, 0.78) ?? secondary;
  }

  static Color heroGradientStart(Color primary) {
    if (primary == appBlue) return appHeroStart;
    return _shiftHsl(
      primary,
      saturationDelta: 0.03,
      lightnessDelta: 0.04,
      minLightness: 0.46,
      maxLightness: 0.60,
    );
  }

  static Color heroGradientEnd(Color primary) {
    if (primary == appBlue) return appHeroEnd;
    return _shiftHsl(
      primary,
      saturationDelta: 0.02,
      lightnessDelta: -0.11,
      minLightness: 0.31,
      maxLightness: 0.46,
    );
  }

  static Color _shiftHsl(
    Color color, {
    required double saturationDelta,
    required double lightnessDelta,
    required double minLightness,
    required double maxLightness,
  }) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation + saturationDelta).clamp(0.0, 1.0))
        .withLightness(
          (hsl.lightness + lightnessDelta).clamp(minLightness, maxLightness),
        )
        .toColor();
  }

  static ThemeData light({
    AppThemeTokens tokens = AppThemeTokens.fallback,
    bool useRuntimeBrandColors = false,
  }) {
    final primary = useRuntimeBrandColors
        ? tokens.primaryColor ?? AppThemeTokens.fallback.primaryColor!
        : AppThemeTokens.fallback.primaryColor!;
    final secondary = useRuntimeBrandColors
        ? tokens.secondaryColor ?? AppThemeTokens.fallback.secondaryColor!
        : AppThemeTokens.fallback.secondaryColor!;
    final tertiary = useRuntimeBrandColors
        ? tokens.accentColor ?? AppThemeTokens.fallback.accentColor!
        : AppThemeTokens.fallback.accentColor!;
    final seed = primary;
    final background =
        tokens.backgroundColor ?? AppThemeTokens.fallback.backgroundColor!;
    final textColor = tokens.textColor ?? AppThemeTokens.fallback.textColor!;
    final fontFamily = useRuntimeBrandColors
        ? (tokens.fontFamily.trim().isEmpty
            ? AppThemeTokens.fallback.fontFamily
            : tokens.fontFamily.trim())
        : AppThemeTokens.fallback.fontFamily;
    final baseScheme = ColorScheme.fromSeed(seedColor: seed);
    final colorScheme = baseScheme.copyWith(
      primary: primary,
      onPrimary: AppTheme.appSheet,
      primaryContainer: Color.lerp(primary, AppTheme.appSheet, 0.88) ?? appSoft,
      onPrimaryContainer: primary,
      secondary: secondary,
      onSecondary: AppTheme.appSheet,
      secondaryContainer: Color.lerp(secondary, AppTheme.appSheet, 0.78) ??
          baseScheme.secondaryContainer,
      onSecondaryContainer: secondary,
      tertiary: tertiary,
      onTertiary: AppTheme.appSheet,
      tertiaryContainer: Color.lerp(tertiary, AppTheme.appSheet, 0.74) ??
          baseScheme.tertiaryContainer,
      onTertiaryContainer: AppTheme.appInk,
      surface: AppTheme.appSheet,
      surfaceContainerLowest: AppTheme.appSheet,
      surfaceContainerLow:
          Color.lerp(background, AppTheme.appSoft, 0.35) ?? AppTheme.appSoft,
      surfaceContainer: Color.lerp(AppTheme.appSheet, AppTheme.appSoft, 0.46) ??
          AppTheme.appSoft,
      surfaceContainerHigh: AppTheme.appSoft,
      surfaceContainerHighest: AppTheme.appSoft,
      onSurface: textColor,
      onSurfaceVariant: AppTheme.appMuted,
      outline: AppTheme.appBorder,
      outlineVariant: AppTheme.appBorder,
      shadow: AppTheme.appInk,
      scrim: AppTheme.appInk,
    );
    final textTheme = _nuxtLikeTextTheme(
      ThemeData.light().textTheme.apply(
            fontFamily: fontFamily,
            bodyColor: textColor,
            displayColor: textColor,
          ),
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        foregroundColor: colorScheme.onPrimary,
        titleTextStyle: ThemeData.light().textTheme.titleLarge?.copyWith(
              color: colorScheme.onPrimary,
              fontFamily: fontFamily,
              fontWeight: FontWeight.w700,
            ),
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        actionsIconTheme: IconThemeData(color: colorScheme.onPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppTheme.appSheet,
        elevation: 0,
        shadowColor: AppTheme.appInk.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.appBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.appSheet,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.appBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: AppTheme.appDisabledAction,
          disabledForegroundColor: colorScheme.onPrimary.withValues(
            alpha: 0.86,
          ),
          minimumSize: const Size(0, 47),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: const StadiumBorder(),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.12,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          disabledForegroundColor: colorScheme.onSurfaceVariant,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: const StadiumBorder(),
          side: BorderSide(color: colorScheme.primary),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.12,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStateProperty.resolveWith((states) {
            final disabled = states.contains(WidgetState.disabled);
            return BorderSide(
              color: disabled ? AppTheme.appBorder : colorScheme.primary,
            );
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.12,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppTheme.appBorder,
        thickness: 1,
      ),
    );
  }
}

TextTheme _nuxtLikeTextTheme(TextTheme base) {
  return base.copyWith(
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 16, height: 1.45),
    bodySmall: base.bodySmall?.copyWith(fontSize: 14, height: 1.38),
    labelLarge: base.labelLarge?.copyWith(fontSize: 16, height: 1.2),
    labelMedium: base.labelMedium?.copyWith(fontSize: 14, height: 1.2),
    labelSmall: base.labelSmall?.copyWith(fontSize: 12, height: 1.2),
    titleSmall: base.titleSmall?.copyWith(fontSize: 16, height: 1.25),
    titleMedium: base.titleMedium?.copyWith(fontSize: 18, height: 1.25),
    titleLarge: base.titleLarge?.copyWith(fontSize: 22, height: 1.2),
    headlineSmall: base.headlineSmall?.copyWith(fontSize: 24, height: 1.2),
    headlineMedium: base.headlineMedium?.copyWith(fontSize: 28, height: 1.2),
    headlineLarge: base.headlineLarge?.copyWith(fontSize: 34, height: 1.15),
  );
}

class AppThemeTokens {
  const AppThemeTokens({
    this.primaryColor,
    this.secondaryColor,
    this.accentColor,
    this.backgroundColor,
    this.textColor,
    this.fontFamily = 'Kanit',
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
    primaryColor: AppTheme.appBlue,
    secondaryColor: AppTheme.appSky,
    accentColor: AppTheme.appYellow,
    backgroundColor: AppTheme.appSheet,
    textColor: AppTheme.appInk,
    fontFamily: 'Kanit',
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
