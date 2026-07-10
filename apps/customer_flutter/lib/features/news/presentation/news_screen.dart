import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../shared/widgets/app_shell.dart';
import '../data/news_models.dart';
import '../data/news_repository.dart';
import 'news_card.dart';
import 'news_page_shell.dart';
import 'news_visual_tokens.dart';

class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  String _noticeMessage = '';

  @override
  Widget build(BuildContext context) {
    final news = ref.watch(newsListProvider);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.newsTitle,
      currentPath: '/news',
      backPath: '/profile',
      heroMinHeight: NewsPageShell.heroMinHeight,
      heroSheetOverlap: NewsPageShell.sheetOverlap,
      heroContent: const SizedBox.shrink(),
      child: NewsPageShell(
        child: news.when(
          data: (items) {
            if (items.isEmpty) return const _EmptyNewsCard();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_noticeMessage.isNotEmpty) ...[
                  NewsInlineNotice(message: _noticeMessage),
                  const SizedBox(height: 12),
                ],
                _NewsCardsList(
                  items: items,
                  onOpenFailed: () => setState(
                    () => _noticeMessage = context.l10n.newsOpenFailed,
                  ),
                ),
              ],
            );
          },
          loading: () => const _NewsListStatePanel.loading(),
          error: (_, __) => const _EmptyNewsCard(),
        ),
      ),
    );
  }
}

class _EmptyNewsCard extends StatelessWidget {
  const _EmptyNewsCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _NewsListStatePanel(
      icon: Icons.newspaper,
      title: l10n.newsEmptyTitle,
      message: l10n.newsEmptyMessage,
    );
  }
}

class _NewsListStatePanel extends StatelessWidget {
  const _NewsListStatePanel({
    required this.message,
    this.title,
    this.icon,
  }) : loading = false;

  const _NewsListStatePanel.loading()
      : message = '',
        title = null,
        icon = null,
        loading = true;

  final IconData? icon;
  final String? title;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = newsBorderColor(context);
    final bodyColor = newsBodyColor(context);
    final surfaceColor = newsCardSurfaceColor(context);
    final titleColor = newsTitleColor(context);
    final effectiveMessage = loading
        ? l10n.newsLoading
        : message.isEmpty
            ? l10n.commonLoadFailed
            : message;
    final effectiveTitle = title;
    final iconColor = colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: newsShadowColor(context),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const NewsLoadingMark(
                key: Key('news-list-loading-mark'),
                size: 46,
              )
            else if (icon != null)
              Icon(
                icon,
                size: 42,
                color: iconColor,
              ),
            if (loading) ...[
              const SizedBox(height: 12),
              const NewsProgressLine(
                key: Key('news-list-loading-progress'),
                width: 128,
              ),
            ],
            if (effectiveTitle != null) ...[
              const SizedBox(height: 10),
              Text(
                effectiveTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: titleColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              effectiveMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: bodyColor,
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

class _NewsCardsList extends StatelessWidget {
  const _NewsCardsList({
    required this.items,
    required this.onOpenFailed,
  });

  final List<NewsItem> items;
  final VoidCallback onOpenFailed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _NewsListCard(
            item: items[index],
            onOpenFailed: onOpenFailed,
          ),
          if (index < items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _NewsListCard extends StatelessWidget {
  const _NewsListCard({
    required this.item,
    required this.onOpenFailed,
  });

  final NewsItem item;
  final VoidCallback onOpenFailed;

  @override
  Widget build(BuildContext context) {
    return NewsSideCard(
      item: item,
      margin: EdgeInsets.zero,
      onOpenFailed: onOpenFailed,
    );
  }
}
