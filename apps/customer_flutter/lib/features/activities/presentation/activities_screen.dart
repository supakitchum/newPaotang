import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/activity_models.dart';
import '../data/activity_repository.dart';
import 'activity_error_message.dart';
import 'activity_localization.dart';

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  final List<ActivityItem> _items = [];
  ActivityListMeta _meta = ActivityListMeta.empty;
  bool _loading = true;
  bool _loadingMore = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppShell(
      title: l10n.homeActivities,
      currentPath: '/activities',
      backPath: '/',
      child: ListView(
        children: [
          CustomerPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loading)
                  _ActivityLoadingCard(message: l10n.activitiesLoading)
                else if (_error.isNotEmpty && _items.isEmpty)
                  _ActivityErrorCard(message: _error, onRetry: _refresh)
                else ...[
                  if (_meta.hasHistory) ...[
                    _ActivityHistoryLink(
                      onPressed: () => context.go('/activities/history'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_items.isEmpty)
                    const _EmptyActivitiesCard()
                  else
                    for (final activity in _items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ActivityListCard(activity: activity),
                      ),
                  if (_error.isNotEmpty)
                    _ActivityInlineError(message: _error, onRetry: _loadMore),
                  if (_meta.hasMore || _loadingMore)
                    _ActivityLoadMoreButton(
                      loading: _loadingMore,
                      onPressed: _loadMore,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() => _load(reset: true);

  Future<void> _loadMore() => _load(reset: false);

  Future<void> _load({required bool reset}) async {
    if (_loadingMore || (_loading && !reset)) return;
    if (!reset && (!_meta.hasMore || (_meta.nextCursor ?? '').isEmpty)) return;

    setState(() {
      if (reset) {
        _loading = true;
        _items.clear();
        _meta = ActivityListMeta.empty;
      } else {
        _loadingMore = true;
      }
      _error = '';
    });

    try {
      final auth = ref.read(authControllerProvider);
      final authenticated = auth.isAuthenticated && !auth.pinRequired;
      final page = await ref.read(activityRepositoryProvider).listPage(
            authenticated: authenticated,
            cursor: reset ? '' : (_meta.nextCursor ?? ''),
          );
      if (!mounted) return;
      setState(() {
        final pageItems = _sortActivitiesByRights(
          page.items,
          authenticated: authenticated,
        );
        if (reset) {
          _items
            ..clear()
            ..addAll(pageItems);
        } else {
          _items.addAll(pageItems);
        }
        _meta = page.meta;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = activityErrorMessage(
          error,
          context.l10n.activitiesLoadFailed,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }
}

class _ActivityHistoryLink extends StatelessWidget {
  const _ActivityHistoryLink({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.history, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.activitiesHistoryTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.activitiesHistoryHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                l10n.commonViewAll,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class ActivitiesHistoryScreen extends ConsumerStatefulWidget {
  const ActivitiesHistoryScreen({super.key});

  @override
  ConsumerState<ActivitiesHistoryScreen> createState() =>
      _ActivitiesHistoryScreenState();
}

class _ActivitiesHistoryScreenState
    extends ConsumerState<ActivitiesHistoryScreen> {
  final List<ActivityItem> _items = [];
  ActivityListMeta _meta = ActivityListMeta.empty;
  bool _loading = true;
  bool _loadingMore = false;
  String _error = '';
  String? _loadedQueryGameId;

  @override
  Widget build(BuildContext context) {
    final queryGameId =
        GoRouterState.of(context).uri.queryParameters['game_id'] ?? '';
    final l10n = context.l10n;

    if (_loadedQueryGameId != queryGameId) {
      _loadedQueryGameId = queryGameId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
    }

    return AppShell(
      title: l10n.activitiesHistoryTitle,
      currentPath: '/activities',
      backPath: '/activities',
      child: ListView(
        children: [
          CustomerPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/activities'),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(l10n.activitiesBackToCurrent),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  _ActivityLoadingCard(message: l10n.activitiesHistoryLoading)
                else if (_error.isNotEmpty && _items.isEmpty)
                  _ActivityErrorCard(message: _error, onRetry: _refresh)
                else ...[
                  _ActivityHistoryGameFilter(
                    games: _meta.games,
                    selectedGameId: _selectedHistoryGameId(
                      meta: _meta,
                      requestedGameId: queryGameId,
                    ),
                    onChanged: (gameId) {
                      final next = gameId ?? '';
                      final uri = Uri(
                        path: '/activities/history',
                        queryParameters:
                            next.isEmpty ? null : {'game_id': next},
                      );
                      context.go(uri.toString());
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    const _EmptyHistoryActivitiesCard()
                  else
                    for (final activity in _items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ActivityListCard(
                          activity: activity,
                          historyGameId: _selectedHistoryGameId(
                            meta: _meta,
                            requestedGameId: queryGameId,
                          ),
                        ),
                      ),
                  if (_error.isNotEmpty)
                    _ActivityInlineError(message: _error, onRetry: _loadMore),
                  if (_meta.hasMore || _loadingMore)
                    _ActivityLoadMoreButton(
                      loading: _loadingMore,
                      onPressed: _loadMore,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() => _load(reset: true);

  Future<void> _loadMore() => _load(reset: false);

  Future<void> _load({required bool reset}) async {
    if (_loadingMore || (_loading && !reset)) return;
    if (!reset && (!_meta.hasMore || (_meta.nextCursor ?? '').isEmpty)) return;

    final gameId = _loadedQueryGameId ?? '';
    setState(() {
      if (reset) {
        _loading = true;
        _items.clear();
        _meta = ActivityListMeta.empty;
      } else {
        _loadingMore = true;
      }
      _error = '';
    });

    try {
      final auth = ref.read(authControllerProvider);
      final authenticated = auth.isAuthenticated && !auth.pinRequired;
      final page = await ref.read(activityRepositoryProvider).listPage(
            authenticated: authenticated,
            history: true,
            gameId: gameId,
            cursor: reset ? '' : (_meta.nextCursor ?? ''),
          );
      if (!mounted) return;
      setState(() {
        final pageItems = _sortActivitiesByRights(
          page.items,
          authenticated: authenticated,
        );
        if (reset) {
          _items
            ..clear()
            ..addAll(pageItems);
        } else {
          _items.addAll(pageItems);
        }
        _meta = page.meta;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = activityErrorMessage(
          error,
          context.l10n.activitiesLoadFailed,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }
}

List<ActivityItem> _sortActivitiesByRights(
  List<ActivityItem> items, {
  required bool authenticated,
}) {
  if (!authenticated) return items;

  final indexed = [
    for (var index = 0; index < items.length; index++)
      MapEntry(index, items[index]),
  ];
  indexed.sort((first, second) {
    final firstHasRight = _hasCurrentActivityRight(first.value);
    final secondHasRight = _hasCurrentActivityRight(second.value);
    final rightCompare = (secondHasRight ? 1 : 0) - (firstHasRight ? 1 : 0);
    return rightCompare == 0 ? first.key.compareTo(second.key) : rightCompare;
  });
  return indexed.map((entry) => entry.value).toList(growable: false);
}

bool _hasCurrentActivityRight(ActivityItem activity) {
  if (activity.isCashback) return activity.hasRight;
  if (!activity.isLuckyBoard) return activity.hasRight;
  return !activity.rights.entryClosed && activity.rights.remainingCount > 0;
}

String _selectedHistoryGameId({
  required ActivityListMeta meta,
  required String requestedGameId,
}) {
  if (requestedGameId.isNotEmpty &&
      meta.games.any((game) => game.id == requestedGameId)) {
    return requestedGameId;
  }
  if (meta.selectedGameId.isNotEmpty &&
      meta.games.any((game) => game.id == meta.selectedGameId)) {
    return meta.selectedGameId;
  }
  return meta.games.isEmpty ? '' : meta.games.first.id;
}

class _ActivityHistoryGameFilter extends StatelessWidget {
  const _ActivityHistoryGameFilter({
    required this.games,
    required this.selectedGameId,
    required this.onChanged,
  });

  final List<ActivityGameOption> games;
  final String selectedGameId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final selectedLabel = games
        .where((game) => game.id == selectedGameId)
        .map((game) => game.label)
        .firstOrNull;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.activitiesHistorySelectLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              selectedLabel ?? l10n.activitiesHistoryTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: games.any((game) => game.id == selectedGameId)
                  ? selectedGameId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              hint: Text(l10n.activitiesHistoryNoGames),
              items: [
                for (final game in games)
                  DropdownMenuItem(
                    value: game.id,
                    child: Text(
                      game.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: games.length < 2 ? null : onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}

class _ActivityLoadingCard extends StatelessWidget {
  const _ActivityLoadingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityErrorCard extends StatelessWidget {
  const _ActivityErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 38),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityInlineError extends StatelessWidget {
  const _ActivityInlineError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityLoadMoreButton extends StatelessWidget {
  const _ActivityLoadMoreButton({
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.expand_more),
        label: Text(
          loading
              ? context.l10n.commonLoadingMore
              : context.l10n.commonLoadMore,
        ),
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
      margin: EdgeInsets.zero,
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
      margin: EdgeInsets.zero,
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
  const _ActivityListCard({
    required this.activity,
    this.historyGameId = '',
  });

  final ActivityItem activity;
  final String historyGameId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final detailUri = Uri(
      path: '/activities/${activity.slug}',
      queryParameters: historyGameId.isEmpty
          ? null
          : {'from': 'history', 'game_id': historyGameId},
    );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: activity.slug.isEmpty
            ? null
            : () => context.go(detailUri.toString()),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 370;
            final imageWidth = compact ? 96.0 : 116.0;
            final imageHeight = compact ? 136.0 : 148.0;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: imageWidth,
                    height: imageHeight,
                    child: activity.imageUrl.isEmpty
                        ? _ActivityImageFallback(activity: activity)
                        : Image.network(
                            activity.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _ActivityImageFallback(activity: activity),
                          ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 12 : 14,
                        12,
                        compact ? 8 : 12,
                        12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ActivityTypeBadge(
                            label: l10n.activityTypeLabel(activity.type),
                            highlighted: activity.hasRight,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            activityDisplayName(l10n, activity),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 1.18,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            activityConditionText(l10n, activity),
                            maxLines: compact ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                      height: 1.32,
                                    ),
                          ),
                          const SizedBox(height: 8),
                          _ActivityMetaPill(
                            label: activityMetaText(l10n, activity),
                            highlighted: activity.hasRight,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: compact ? 4 : 8),
                    child: Icon(
                      Icons.chevron_right,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActivityImageFallback extends StatelessWidget {
  const _ActivityImageFallback({required this.activity});

  final ActivityItem activity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Icon(
        activity.isCashback ? Icons.savings_outlined : Icons.grid_view_rounded,
        color: colorScheme.primary,
        size: 34,
      ),
    );
  }
}

class _ActivityTypeBadge extends StatelessWidget {
  const _ActivityTypeBadge({
    required this.label,
    required this.highlighted,
  });

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = highlighted ? Colors.white : colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted
            ? colorScheme.primary
            : colorScheme.primaryContainer.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _ActivityMetaPill extends StatelessWidget {
  const _ActivityMetaPill({
    required this.label,
    required this.highlighted,
  });

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground =
        highlighted ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Flexible(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: highlighted
                  ? colorScheme.primaryContainer.withValues(alpha: 0.56)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
