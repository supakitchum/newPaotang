import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../shared/widgets/app_shell.dart';
import '../data/news_models.dart';
import '../data/news_repository.dart';
import 'news_card.dart';
import 'news_error_message.dart';
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
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _NewsListCard(
                      item: item,
                      onOpenFailed: () => setState(
                        () => _noticeMessage = context.l10n.newsOpenFailed,
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const _NewsListStatePanel.loading(),
          error: (error, _) => _NewsListStatePanel.error(
            message: newsErrorMessage(error, l10n.newsLoadFailedMessage),
            onRetry: () => ref.invalidate(newsListProvider),
          ),
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
  })  : onRetry = null,
        loading = false;

  const _NewsListStatePanel.loading()
      : message = '',
        title = null,
        icon = null,
        onRetry = null,
        loading = true;

  const _NewsListStatePanel.error({
    required this.message,
    required this.onRetry,
  })  : title = null,
        icon = Icons.error_outline,
        loading = false;

  final IconData? icon;
  final String? title;
  final String message;
  final VoidCallback? onRetry;
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
    final effectiveTitle =
        icon == Icons.error_outline ? l10n.newsLoadFailedTitle : title;
    final iconColor =
        icon == Icons.error_outline ? colorScheme.error : colorScheme.primary;

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
                      color: icon == Icons.error_outline
                          ? colorScheme.error
                          : titleColor,
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
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                style: _newsOutlinePillStyle(context),
                onPressed: onRetry,
                child: Text(l10n.commonRetry),
              ),
            ],
          ],
        ),
      ),
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

ButtonStyle _newsOutlinePillStyle(BuildContext context) {
  return OutlinedButton.styleFrom(
    minimumSize: const Size(160, 44),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    shape: const StadiumBorder(),
    side: BorderSide(color: Theme.of(context).colorScheme.primary),
    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
        ),
  );
}
