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
    this.imageWidth = 112,
    this.imageHeight = 124,
    this.showCategory = true,
    this.summaryMaxLines = 2,
    this.margin,
    this.onOpenFailed,
  });

  final NewsItem item;
  final double imageWidth;
  final double imageHeight;
  final bool showCategory;
  final int summaryMaxLines;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onOpenFailed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final borderColor = newsBorderColor(context);
    final shadowColor = newsShadowColor(context);
    final surfaceColor = newsCardSurfaceColor(context);
    final titleColor = newsTitleColor(context);
    final bodyColor = newsBodyColor(context);
    final mutedColor = newsMutedColor(context);
    final title = item.title.isEmpty ? l10n.newsFallbackTitle : item.title;
    final publishedAt = formatLocalizedDateTime(
      item.publishedAt,
      localeTag(l10n.locale),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= 380;
        final resolvedImageWidth = compact ? 96.0 : imageWidth;
        final resolvedChevronWidth = compact ? 24.0 : 28.0;
        final resolvedIconSize = resolvedImageWidth >= 104 ? 31.0 : 25.0;
        final radius = BorderRadius.circular(16);

        return Padding(
          padding: margin ?? EdgeInsets.zero,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border.all(color: borderColor),
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: hasNewsTarget(item)
                      ? () => _openNews(context, ref)
                      : null,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: imageHeight),
                    child: Row(
                      children: [
                        SizedBox(
                          width: resolvedImageWidth,
                          height: imageHeight,
                          child: item.coverUrl.isEmpty
                              ? NewsFallbackArtwork(
                                  iconSize: resolvedIconSize,
                                )
                              : Image.network(
                                  item.coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      NewsFallbackArtwork(
                                    iconSize: resolvedIconSize,
                                  ),
                                ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (showCategory) ...[
                                  Text(
                                    l10n.newsCategory,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          height: 1,
                                        ),
                                  ),
                                  const SizedBox(height: 5),
                                ],
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: titleColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        height: 1.35,
                                      ),
                                ),
                                if (publishedAt.isNotEmpty &&
                                    publishedAt != '-') ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    publishedAt,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: mutedColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                        ),
                                  ),
                                ],
                                if (item.summary.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    item.summary,
                                    maxLines: summaryMaxLines,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: bodyColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          height: 1.38,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: resolvedChevronWidth,
                          child: Icon(
                            Icons.chevron_right,
                            color: Theme.of(context).colorScheme.primary,
                            size: 22,
                          ),
                        ),
                      ],
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
      context.go(internalPath);
      return;
    }

    final externalUri = newsExternalUri(item);
    if (externalUri == null) return;

    final ok = await ref.read(customerLinkLauncherProvider).openExternal(
          externalUri,
        );
    if (!context.mounted || ok) return;
    onOpenFailed?.call();
  }
}

class NewsInlineNotice extends StatelessWidget {
  const NewsInlineNotice({
    required this.message,
    super.key,
    this.margin,
  });

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
