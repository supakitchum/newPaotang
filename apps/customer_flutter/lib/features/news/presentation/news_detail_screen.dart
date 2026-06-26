import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../data/news_models.dart';
import '../data/news_repository.dart';

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
      child: AsyncStateView(
        value: news,
        data: (item) => _NewsDetailBody(item: item),
        empty: const _NewsMissingCard(),
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
    final title = item.title.isEmpty ? l10n.newsFallbackTitle : item.title;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (item.coverUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(item.coverUrl, fit: BoxFit.cover),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          formatLocalizedDateTime(item.publishedAt, localeTag(l10n.locale)),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
        if (item.summary.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            item.summary,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              item.body.isNotEmpty ? item.body : item.summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.55,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NewsMissingCard extends StatelessWidget {
  const _NewsMissingCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Text(context.l10n.newsMissing),
          ),
        ),
      ),
    );
  }
}
