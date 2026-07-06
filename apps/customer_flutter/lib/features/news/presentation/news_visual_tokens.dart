import 'package:flutter/material.dart';

Color newsCardSurfaceColor(BuildContext context) {
  return Theme.of(context).cardTheme.color ??
      Theme.of(context).colorScheme.surface;
}

Color newsTitleColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurface;
}

Color newsBodyColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}

Color newsMutedColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.72);
}

Color newsBorderColor(BuildContext context) {
  return Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.82);
}

Color newsShadowColor(BuildContext context) {
  return Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
}

Color newsNoticeBackgroundColor(BuildContext context) {
  return Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.48);
}

Color newsNoticeBorderColor(BuildContext context) {
  return Theme.of(context).colorScheme.error.withValues(alpha: 0.22);
}

Color newsNoticeForegroundColor(BuildContext context) {
  return Theme.of(context).colorScheme.onErrorContainer;
}

Color newsFallbackSparkColor(BuildContext context) {
  return Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.78);
}

class NewsFallbackArtwork extends StatelessWidget {
  const NewsFallbackArtwork({
    super.key,
    this.iconSize = 31,
  });

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
            colorScheme.primary,
            Color.lerp(colorScheme.primary, colorScheme.secondary, 0.46) ??
                colorScheme.primary,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 8,
            top: 10,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: newsFallbackSparkColor(context),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.campaign,
              size: iconSize,
              color: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class NewsLoadingMark extends StatelessWidget {
  const NewsLoadingMark({
    super.key,
    this.icon = Icons.campaign_outlined,
    this.size = 44,
  });

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final start = Color.lerp(colorScheme.primary, colorScheme.surface, 0.84) ??
        colorScheme.primary.withValues(alpha: 0.16);
    final end = Color.lerp(colorScheme.tertiary, colorScheme.surface, 0.9) ??
        colorScheme.tertiary.withValues(alpha: 0.10);

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

class NewsProgressLine extends StatelessWidget {
  const NewsProgressLine({
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
                            colorScheme.tertiary,
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

class NewsImageLoadingFrame extends StatelessWidget {
  const NewsImageLoadingFrame({
    super.key,
    this.aspectRatio = 1,
  });

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: newsCardSurfaceColor(context),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              NewsLoadingMark(size: 34),
              SizedBox(height: 8),
              NewsProgressLine(width: 76, height: 3, fillFactor: 0.52),
            ],
          ),
        ),
      ),
    );
  }
}
