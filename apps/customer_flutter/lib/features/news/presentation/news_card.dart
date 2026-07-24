import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../data/news_models.dart';
import 'news_link_target.dart';
import 'news_visual_tokens.dart';

class NewsSideCard extends ConsumerWidget {
  const NewsSideCard({
    required this.item,
    super.key,
    this.showCategory = true,
    this.summaryMaxLines = 3,
    this.margin,
    this.onOpenFailed,
  });

  final NewsItem item;
  final bool showCategory;
  final int summaryMaxLines;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onOpenFailed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final titleColor = newsTitleColor(context);
    final bodyColor = newsBodyColor(context);
    final mutedColor = newsMutedColor(context);
    final title = item.title.isEmpty ? l10n.newsFallbackTitle : item.title;
    final publishedAt = formatBangkokLocalizedDateTime(
      item.publishedAt,
      localeTag(l10n.locale),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final wide = constraints.maxWidth >= 680;
        final canOpen = hasNewsTarget(item);
        final radius = BorderRadius.circular(12);
        final media = _NewsCardMedia(imageUrl: item.coverUrl, wide: wide);
        final content = _NewsCardContent(
          title: title,
          summary: item.summary,
          publishedAt: publishedAt,
          showCategory: showCategory,
          summaryMaxLines: summaryMaxLines,
          canOpen: canOpen,
          compact: compact,
          wide: wide,
          titleColor: titleColor,
          bodyColor: bodyColor,
          mutedColor: mutedColor,
        );

        return Padding(
          padding: margin ?? EdgeInsets.zero,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Semantics(
                button: canOpen,
                enabled: canOpen,
                label: title,
                child: MouseRegion(
                  cursor: canOpen
                      ? SystemMouseCursors.click
                      : MouseCursor.defer,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: canOpen ? () => _openNews(context, ref) : null,
                    child: DecoratedBox(
                      key: const ValueKey('news-card-surface'),
                      decoration: BoxDecoration(
                        color: newsCardSurfaceColor(context),
                        border: Border.all(color: newsBorderColor(context)),
                        borderRadius: radius,
                        boxShadow: [
                          BoxShadow(
                            color: newsShadowColor(context),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: radius,
                        child: wide
                            ? SizedBox(
                                height: 216,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(flex: 5, child: media),
                                    Expanded(flex: 7, child: content),
                                  ],
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [media, content],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openNews(BuildContext context, WidgetRef ref) async {
    final internalPath = newsInternalPath(item);
    if (internalPath != null) {
      context.push(internalPath);
      return;
    }

    final externalUri = newsExternalUri(item);
    if (externalUri == null) return;

    final ok = await ref
        .read(customerLinkLauncherProvider)
        .openExternal(externalUri);
    if (!context.mounted || ok) return;
    onOpenFailed?.call();
  }
}

class _NewsCardMedia extends StatelessWidget {
  const _NewsCardMedia({required this.imageUrl, required this.wide});

  final String imageUrl;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl.isEmpty
        ? const NewsFallbackArtwork(iconSize: 44)
        : Image.network(
            imageUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return NewsImageLoadingFrame(aspectRatio: wide ? 5 / 7 : 16 / 9);
            },
            errorBuilder: (_, __, ___) =>
                const NewsFallbackArtwork(iconSize: 44),
          );

    if (wide) {
      return SizedBox.expand(
        key: const ValueKey('news-card-media'),
        child: image,
      );
    }
    return AspectRatio(
      key: const ValueKey('news-card-media'),
      aspectRatio: 16 / 9,
      child: image,
    );
  }
}

class _NewsCardContent extends StatelessWidget {
  const _NewsCardContent({
    required this.title,
    required this.summary,
    required this.publishedAt,
    required this.showCategory,
    required this.summaryMaxLines,
    required this.canOpen,
    required this.compact,
    required this.wide,
    required this.titleColor,
    required this.bodyColor,
    required this.mutedColor,
  });

  final String title;
  final String summary;
  final String publishedAt;
  final bool showCategory;
  final int summaryMaxLines;
  final bool canOpen;
  final bool compact;
  final bool wide;
  final Color titleColor;
  final Color bodyColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final hasDate = publishedAt.isNotEmpty && publishedAt != '-';
    return Padding(
      key: const ValueKey('news-card-content'),
      padding: EdgeInsets.fromLTRB(
        wide ? 24 : 16,
        wide ? 20 : 16,
        wide ? 22 : 16,
        wide ? 20 : 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: wide
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showCategory)
                Flexible(
                  child: Text(
                    context.l10n.newsCategory,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: newsCategoryColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              if (showCategory && hasDate)
                Container(
                  width: 3,
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: mutedColor,
                    shape: BoxShape.circle,
                  ),
                ),
              if (hasDate)
                Flexible(
                  flex: 2,
                  child: Text(
                    publishedAt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: mutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: wide ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: titleColor,
                    fontSize: compact ? 17 : 19,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              if (canOpen) ...[
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: newsCategoryColor(context),
                    size: 16,
                  ),
                ),
              ],
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary,
              maxLines: wide ? 3 : summaryMaxLines,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: bodyColor,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NewsInlineNotice extends StatelessWidget {
  const NewsInlineNotice({required this.message, super.key, this.margin});

  final String message;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: newsNoticeBackgroundColor(context),
          border: Border.all(color: newsNoticeBorderColor(context)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: newsNoticeForegroundColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
