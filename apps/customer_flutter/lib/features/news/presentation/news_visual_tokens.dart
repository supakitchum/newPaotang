import 'package:flutter/material.dart';

const newsNuxtSurface = Color(0xFFFFFFFF);
const newsNuxtListBorder = Color(0xFFDBE7F5);
const newsNuxtListShadow = Color(0x14213755);
const newsNuxtDetailShadow = Color(0x1F083068);
const newsNuxtListTitle = Color(0xFF17335F);
const newsNuxtDetailTitle = Color(0xFF1F2937);
const newsNuxtCategory = Color(0xFF0B69DC);
const newsNuxtDetailKicker = Color(0xFF0875DF);
const newsNuxtListBody = Color(0xFF64748B);
const newsNuxtDetailSummary = Color(0xFF53616F);
const newsNuxtDetailBody = Color(0xFF344054);
const newsNuxtDetailEmptyBody = Color(0xFF6B7280);
const newsNuxtMuted = Color(0xFF8A97A7);
const newsNuxtFallbackBlueStart = Color(0xFF0B84ED);
const newsNuxtFallbackBlueEnd = Color(0xFF174783);
const newsNuxtFallbackSpark = Color(0xD1FFD240);
const newsNuxtModalOverlay = Color(0x9E040A14);
const newsNuxtModalCloseForeground = Color(0xFF1D2A3A);
const newsNuxtModalCloseShadow = Color(0x3805132C);
const newsNuxtModalImageShadow = Color(0x47000000);

Color newsCardSurfaceColor(BuildContext context) {
  return newsNuxtSurface;
}

Color newsTitleColor(BuildContext context) {
  return newsNuxtListTitle;
}

Color newsBodyColor(BuildContext context) {
  return newsNuxtListBody;
}

Color newsMutedColor(BuildContext context) {
  return newsNuxtMuted;
}

Color newsBorderColor(BuildContext context) {
  return newsNuxtListBorder;
}

Color newsShadowColor(BuildContext context) {
  return newsNuxtListShadow;
}

Color newsDetailTitleColor(BuildContext context) {
  return newsNuxtDetailTitle;
}

Color newsDetailSummaryColor(BuildContext context) {
  return newsNuxtDetailSummary;
}

Color newsDetailBodyColor(BuildContext context) {
  return newsNuxtDetailBody;
}

Color newsDetailEmptyBodyColor(BuildContext context) {
  return newsNuxtDetailEmptyBody;
}

Color newsDetailShadowColor(BuildContext context) {
  return newsNuxtDetailShadow;
}

Color newsCategoryColor(BuildContext context) {
  return newsNuxtCategory;
}

Color newsDetailKickerColor(BuildContext context) {
  return newsNuxtDetailKicker;
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
  return newsNuxtFallbackSpark;
}

class NewsFallbackArtwork extends StatelessWidget {
  const NewsFallbackArtwork({
    super.key,
    this.iconSize = 31,
  });

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            newsNuxtFallbackBlueStart,
            newsNuxtFallbackBlueEnd,
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
              color: newsNuxtSurface,
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
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFFE8F6FF),
            Color(0xFFFFFBEB),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(
          color: newsNuxtListBorder,
        ),
      ),
      child: Icon(
        icon,
        color: newsNuxtCategory,
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
    final safeFill = fillFactor.clamp(0.0, 1.0).toDouble();

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FF),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: safeFill,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const [
                      newsNuxtCategory,
                      newsNuxtFallbackBlueStart,
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
            colors: const [
              Color(0xFFE8F6FF),
              Color(0xFFFFFBEB),
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
