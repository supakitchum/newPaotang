import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../data/news_models.dart';
import '../data/news_repository.dart';

class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final news = ref.watch(newsListProvider);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.newsTitle,
      currentPath: '/news',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncStateView(
            value: news,
            data: (items) {
              if (items.isEmpty) return const _EmptyNewsCard();
              return Column(
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _NewsListCard(item: item),
                    ),
                ],
              );
            },
            empty: const _EmptyNewsCard(),
          ),
        ],
      ),
    );
  }
}

class _EmptyNewsCard extends StatelessWidget {
  const _EmptyNewsCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.newspaper, size: 42),
            const SizedBox(height: 12),
            Text(l10n.newsEmptyTitle),
            const SizedBox(height: 4),
            Text(l10n.newsEmptyMessage),
          ],
        ),
      ),
    );
  }
}

class _NewsListCard extends StatelessWidget {
  const _NewsListCard({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = item.title.isEmpty ? l10n.newsFallbackTitle : item.title;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            item.slug.isEmpty ? null : () => context.go('/news/${item.slug}'),
        child: Row(
          children: [
            SizedBox(
              width: 112,
              height: 118,
              child: item.coverUrl.isEmpty
                  ? ColoredBox(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.campaign,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  : Image.network(item.coverUrl, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.newsCategory,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      formatLocalizedDateTime(
                        item.publishedAt,
                        localeTag(l10n.locale),
                      ),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (item.summary.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
