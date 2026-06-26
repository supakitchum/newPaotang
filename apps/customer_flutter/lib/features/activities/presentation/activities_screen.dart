import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../data/activity_models.dart';
import '../data/activity_repository.dart';
import 'activity_localization.dart';

class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(activityListProvider);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.homeActivities,
      currentPath: '/activities',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: () => context.go('/activities/history'),
            icon: const Icon(Icons.history),
            label: Text(l10n.activitiesHistoryButton),
          ),
          const SizedBox(height: 12),
          AsyncStateView(
            value: activities,
            data: (items) {
              if (items.isEmpty) return const _EmptyActivitiesCard();
              return Column(
                children: [
                  for (final activity in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ActivityListCard(activity: activity),
                    ),
                ],
              );
            },
            empty: const _EmptyActivitiesCard(),
          ),
        ],
      ),
    );
  }
}

class ActivitiesHistoryScreen extends ConsumerWidget {
  const ActivitiesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(activityHistoryProvider(''));
    final l10n = context.l10n;

    return AppShell(
      title: l10n.activitiesHistoryTitle,
      currentPath: '/activities',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: () => context.go('/activities'),
            icon: const Icon(Icons.arrow_back),
            label: Text(l10n.activitiesBackToCurrent),
          ),
          const SizedBox(height: 12),
          AsyncStateView(
            value: activities,
            data: (items) {
              if (items.isEmpty) return const _EmptyHistoryActivitiesCard();
              return Column(
                children: [
                  for (final activity in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ActivityListCard(activity: activity),
                    ),
                ],
              );
            },
            empty: const _EmptyHistoryActivitiesCard(),
          ),
        ],
      ),
    );
  }
}

class _EmptyActivitiesCard extends StatelessWidget {
  const _EmptyActivitiesCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.card_giftcard, size: 42),
            const SizedBox(height: 12),
            Text(l10n.activitiesEmptyTitle),
            const SizedBox(height: 4),
            Text(
              l10n.activitiesEmptyMessage,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistoryActivitiesCard extends StatelessWidget {
  const _EmptyHistoryActivitiesCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.history, size: 42),
            const SizedBox(height: 12),
            Text(l10n.activitiesHistoryEmptyTitle),
            const SizedBox(height: 4),
            Text(
              l10n.activitiesHistoryEmptyMessage,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityListCard extends StatelessWidget {
  const _ActivityListCard({required this.activity});

  final ActivityItem activity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: activity.slug.isEmpty
            ? null
            : () => context.go('/activities/${activity.slug}'),
        child: Row(
          children: [
            SizedBox(
              width: 112,
              height: 132,
              child: activity.imageUrl.isEmpty
                  ? ColoredBox(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.stars_rounded,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  : Image.network(activity.imageUrl, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Chip(
                      label: Text(l10n.activityTypeLabel(activity.type)),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activityDisplayName(l10n, activity),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activityConditionText(l10n, activity),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activityMetaText(l10n, activity),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
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
