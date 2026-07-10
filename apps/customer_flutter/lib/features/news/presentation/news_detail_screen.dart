import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../data/news_models.dart';
import '../data/news_repository.dart';
import 'news_page_shell.dart';
import 'news_visual_tokens.dart';

class NewsDetailScreen extends ConsumerWidget {
  const NewsDetailScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final news = ref.watch(newsDetailProvider(slug));
    final l10n = context.l10n;

    return AppShell(
      title: l10n.newsDetailTitle,
      currentPath: '/news',
      backPath: '/news',
      heroMinHeight: NewsPageShell.heroMinHeight,
      heroSheetOverlap: NewsPageShell.sheetOverlap,
      heroContent: const SizedBox.shrink(),
      child: news.when(
        data: (item) => _NewsDetailBody(item: item),
        loading: () => const NewsPageShell(
          child: _NewsDetailLoadingCard(),
        ),
        error: (_, __) => const NewsPageShell(
          child: _NewsMissingCard(),
        ),
      ),
    );
  }
}

class _NewsDetailBody extends StatelessWidget {
  const _NewsDetailBody({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mutedColor = newsMutedColor(context);
    final surfaceColor = newsCardSurfaceColor(context);
    final title = item.title.isEmpty ? l10n.newsFallbackTitle : item.title;
    final locale = localeTag(l10n.locale);
    final displayWindow = _displayWindow(item, locale);
    final paragraphs = _bodyParagraphs(item);
    final imageUrl =
        item.detailImageUrl.isNotEmpty ? item.detailImageUrl : item.coverUrl;

    return NewsPageShell(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: newsDetailShadowColor(context),
              blurRadius: 34,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (imageUrl.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 560),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    frameBuilder: (
                      context,
                      child,
                      frame,
                      wasSynchronouslyLoaded,
                    ) {
                      if (wasSynchronouslyLoaded || frame != null) {
                        return child;
                      }
                      return const NewsImageLoadingFrame(
                        aspectRatio: 16 / 9,
                      );
                    },
                    errorBuilder: (_, __, ___) => const AspectRatio(
                      aspectRatio: 16 / 9,
                      child: NewsFallbackArtwork(iconSize: 52),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.newsDetailCategory,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: newsDetailKickerColor(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: newsDetailTitleColor(context),
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                              ),
                    ),
                    if (item.summary.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        item.summary,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: newsDetailSummaryColor(context),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.55,
                                ),
                      ),
                    ],
                    if (displayWindow.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        displayWindow,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: mutedColor,
                              fontSize: 13,
                              height: 1.3,
                            ),
                      ),
                    ],
                    if (paragraphs.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _NewsBodyParagraphs(paragraphs: paragraphs),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsBodyParagraphs extends StatelessWidget {
  const _NewsBodyParagraphs({required this.paragraphs});

  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < paragraphs.length; index++) ...[
          Text(
            paragraphs[index],
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: newsDetailBodyColor(context),
                  fontSize: 16,
                  height: 1.72,
                ),
          ),
          if (index < paragraphs.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _NewsDetailLoadingCard extends StatelessWidget {
  const _NewsDetailLoadingCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _stateCardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NewsLoadingMark(
              key: Key('news-detail-loading-mark'),
              icon: Icons.article_outlined,
              size: 46,
            ),
            const SizedBox(height: 12),
            const NewsProgressLine(
              key: Key('news-detail-loading-progress'),
              width: 128,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.newsLoading,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: newsBodyColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsMissingCard extends StatelessWidget {
  const _NewsMissingCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: _stateCardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.newsMissingTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: newsDetailTitleColor(context),
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.newsMissingMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: newsDetailEmptyBodyColor(context),
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 20),
            _NewsPrimaryPill(
              label: l10n.newsBackToList,
              onPressed: () => context.go('/news'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsPrimaryPill extends StatelessWidget {
  const _NewsPrimaryPill({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(999);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220, minHeight: 47),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            colors: [
              colorScheme.primary,
              Color.lerp(colorScheme.primary, colorScheme.secondary, 0.38) ??
                  colorScheme.primary,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onPressed,
            child: SizedBox(
              height: 47,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w900,
                        ),
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

BoxDecoration _stateCardDecoration(BuildContext context) {
  return BoxDecoration(
    color: newsCardSurfaceColor(context),
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: newsDetailShadowColor(context),
        blurRadius: 34,
        offset: const Offset(0, 16),
      ),
    ],
  );
}

String _displayWindow(NewsItem item, String localeTag) {
  final start = _formatNewsDate(item.publishedAt, localeTag);
  final end = _formatNewsDate(item.displayEndAt, localeTag);

  if (start.isNotEmpty && end.isNotEmpty) return '$start - $end';
  return start;
}

String _formatNewsDate(Object? value, String localeTag) {
  final formatted = formatLocalizedDateTime(value, localeTag);
  return formatted == '-' ? '' : formatted;
}

List<String> _bodyParagraphs(NewsItem item) {
  final body = _normalizeNewsBodyText(item.body);
  final summary = _normalizeNewsBodyText(item.summary);
  if (body.isEmpty || body == summary) return const [];

  return body
      .split(RegExp(r'\n{2,}|\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && line != summary)
      .toList(growable: false);
}

String _normalizeNewsBodyText(String value) {
  final decoded = _decodeNewsHtmlEntities(value.trim());
  if (decoded.isEmpty) return '';

  final withBreaks = decoded
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(
          r'</\s*(p|div|li|h[1-6]|section|article|ul|ol)\s*>',
          caseSensitive: false,
        ),
        '\n\n',
      )
      .replaceAll(
        RegExp(
          r'<\s*(p|div|li|h[1-6]|section|article|ul|ol)(\s[^>]*)?>',
          caseSensitive: false,
        ),
        '',
      );

  return _decodeNewsHtmlEntities(
    withBreaks.replaceAll(RegExp(r'<[^>]+>'), ''),
  )
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join('\n\n');
}

String _decodeNewsHtmlEntities(String value) {
  var decoded = value;
  for (var index = 0; index < 2; index++) {
    final next = decoded
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#34;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    if (next == decoded) break;
    decoded = next;
  }
  return decoded;
}
