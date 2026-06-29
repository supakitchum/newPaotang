import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../data/news_models.dart';

class NewsSideCard extends StatelessWidget {
  const NewsSideCard({
    required this.item,
    super.key,
    this.imageWidth = 112,
    this.imageHeight = 118,
    this.showCategory = true,
    this.summaryMaxLines = 2,
    this.margin,
  });

  final NewsItem item;
  final double imageWidth;
  final double imageHeight;
  final bool showCategory;
  final int summaryMaxLines;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = item.title.isEmpty ? l10n.newsFallbackTitle : item.title;
    final publishedAt = formatLocalizedDateTime(
      item.publishedAt,
      localeTag(l10n.locale),
    );

    return Card(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            item.slug.isEmpty ? null : () => context.go('/news/${item.slug}'),
        child: Row(
          children: [
            SizedBox(
              width: imageWidth,
              height: imageHeight,
              child: item.coverUrl.isEmpty
                  ? _NewsImageFallback(iconSize: imageWidth >= 104 ? 30 : 24)
                  : Image.network(item.coverUrl, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showCategory) ...[
                      Text(
                        l10n.newsCategory,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (publishedAt.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        publishedAt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                    if (item.summary.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.summary,
                        maxLines: summaryMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsImageFallback extends StatelessWidget {
  const _NewsImageFallback({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(
        Icons.campaign,
        size: iconSize,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}
