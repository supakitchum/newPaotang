import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

Color activityBrandActionFill(ColorScheme colorScheme) =>
    AppTheme.activityActionFill(colorScheme.primary);

Color activityBrandActionForeground(ColorScheme colorScheme) =>
    AppTheme.activityActionText(colorScheme.primary);

Color activityFallbackArtworkStart(ColorScheme colorScheme) =>
    AppTheme.activityFallbackStart(colorScheme.primary);

Color activityFallbackArtworkEnd(ColorScheme colorScheme) =>
    AppTheme.activityFallbackEnd(
      colorScheme.primary,
      colorScheme.secondary,
    );

Color activityFallbackArtworkIcon(ColorScheme colorScheme) =>
    AppTheme.activityFallbackIcon(colorScheme.primary);

Color activitySuccessTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.primary, colorScheme.surface, 0.88) ??
    colorScheme.primary.withValues(alpha: 0.12);

Color activitySuccessForeground(ColorScheme colorScheme) => colorScheme.primary;

Color activityInfoTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.secondary, colorScheme.surface, 0.88) ??
    colorScheme.secondary.withValues(alpha: 0.12);

Color activityInfoForeground(ColorScheme colorScheme) => colorScheme.secondary;

Color activityWarningTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.tertiary, colorScheme.surface, 0.86) ??
    colorScheme.tertiary.withValues(alpha: 0.14);

Color activityWarningBorder(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.tertiary, colorScheme.surface, 0.62) ??
    colorScheme.tertiary.withValues(alpha: 0.38);

Color activityWarningForeground(ColorScheme colorScheme) =>
    colorScheme.tertiary;

Color activityErrorTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.error, colorScheme.surface, 0.88) ??
    colorScheme.errorContainer.withValues(alpha: 0.52);

Color activityErrorBorder(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.error, colorScheme.surface, 0.68) ??
    colorScheme.error.withValues(alpha: 0.32);

Color activityErrorForeground(ColorScheme colorScheme) => colorScheme.error;

class ActivityImageFallback extends StatelessWidget {
  const ActivityImageFallback({
    required this.isCashback,
    super.key,
    this.iconSize = 34,
  });

  final bool isCashback;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            activityFallbackArtworkStart(colorScheme),
            activityFallbackArtworkEnd(colorScheme),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.card_giftcard_outlined,
          color: activityFallbackArtworkIcon(colorScheme),
          size: iconSize,
        ),
      ),
    );
  }
}

class ActivityLoadingMark extends StatelessWidget {
  const ActivityLoadingMark({
    super.key,
    this.icon = Icons.local_activity_outlined,
    this.size = 44,
  });

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final start = Color.lerp(colorScheme.primary, colorScheme.surface, 0.84) ??
        colorScheme.primary.withValues(alpha: 0.16);
    final end = Color.lerp(colorScheme.secondary, colorScheme.surface, 0.9) ??
        colorScheme.secondary.withValues(alpha: 0.10);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Icon(
        icon,
        color: colorScheme.primary,
        size: size * 0.48,
      ),
    );
  }
}

class ActivityProgressLine extends StatelessWidget {
  const ActivityProgressLine({
    super.key,
    this.width = 118,
    this.height = 4,
    this.fillFactor = 0.44,
  });

  final double width;
  final double height;
  final double fillFactor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final safeFill = fillFactor.clamp(0.0, 1.0).toDouble();

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.10),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: safeFill,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      Color.lerp(
                            colorScheme.primary,
                            colorScheme.secondary,
                            0.34,
                          ) ??
                          colorScheme.primary,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ActivityImageLoadingFrame extends StatelessWidget {
  const ActivityImageLoadingFrame({
    super.key,
    this.aspectRatio = 16 / 9,
  });

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.08),
              colorScheme.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ActivityLoadingMark(size: 34),
              const SizedBox(height: 8),
              ActivityProgressLine(
                width: 76,
                height: 3,
                fillFactor: 0.52,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
