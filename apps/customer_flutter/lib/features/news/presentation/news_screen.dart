import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/news_models.dart';
import '../data/news_repository.dart';
import 'news_card.dart';

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
        children: [
          CustomerPageBody(
            child: AsyncStateView(
              value: news,
              data: (items) {
                if (items.isEmpty) return const _EmptyNewsCard();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
      margin: EdgeInsets.zero,
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
    return NewsSideCard(item: item, margin: EdgeInsets.zero);
  }
}
