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
import 'activity_visual_tokens.dart';

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
  bool _refreshing = false;
  String _error = '';
  String _refreshError = '';
  String _loadMoreError = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rightsAccess =
        _activityRightsAccess(ref.watch(authControllerProvider));

    return AppShell(
      title: l10n.homeActivities,
      currentPath: '/activities',
      backPath: '/',
      child: _ActivitiesPageList(
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
            else ...[
              if (_refreshError.isNotEmpty) ...[
                _ActivityInlineError(message: _refreshError, onRetry: _refresh),
                const SizedBox(height: 12),
              ],
              for (final activity in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ActivityListCard(
                    activity: activity,
                    rightsAccess: rightsAccess,
                  ),
                ),
            ],
            if (_loadMoreError.isNotEmpty)
              _ActivityInlineError(message: _loadMoreError, onRetry: _loadMore),
            if (_meta.hasMore || _loadingMore)
              _ActivityLoadMoreButton(
                loading: _loadingMore,
                onPressed: _loadMore,
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _refresh() => _load(
        reset: true,
        showLoading: false,
        preserveDataOnError: true,
      );

  Future<void> _loadMore() => _load(reset: false);

  Future<void> _load({
    required bool reset,
    bool showLoading = true,
    bool preserveDataOnError = false,
  }) async {
    if (_loadingMore || (_loading && !reset) || (reset && _refreshing)) return;
    if (!reset && (!_meta.hasMore || (_meta.nextCursor ?? '').isEmpty)) return;

    if (reset) _refreshing = true;
    final shouldShowBlockingLoading = reset && (showLoading || _items.isEmpty);
    setState(() {
      if (reset) {
        if (shouldShowBlockingLoading) {
          _loading = true;
          _items.clear();
          _meta = ActivityListMeta.empty;
        }
      } else {
        _loadingMore = true;
      }
      _error = '';
      _refreshError = '';
      _loadMoreError = '';
    });

    try {
      final auth = ref.read(authControllerProvider);
      final authenticated =
          _activityRightsAccess(auth) == _ActivityRightsAccess.ready;
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
      final message = activityErrorMessage(
        error,
        context.l10n.activitiesLoadFailed,
      );
      setState(() {
        if (reset) {
          if (preserveDataOnError && _items.isNotEmpty) {
            _refreshError = message;
          } else {
            _error = message;
          }
        } else {
          _loadMoreError = message;
        }
      });
    } finally {
      if (reset) _refreshing = false;
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }
}

class _ActivitiesPageList extends StatelessWidget {
  const _ActivitiesPageList({required this.children});

  static const _heroHeight = 214.0;
  static const _sheetOverlap = 42.0;
  static const _bottomPadding = 118.0;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            const _ActivitiesHeroBand(),
            Padding(
              padding: const EdgeInsets.only(top: _heroHeight - _sheetOverlap),
              child: CustomerPageBody(
                maxWidth: 640,
                top: 8,
                bottom: _bottomPadding,
                mobileHorizontal: 12,
                wideHorizontal: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActivitiesHeroBand extends StatelessWidget {
  const _ActivitiesHeroBand();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _ActivitiesPageList._heroHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              Color.lerp(colorScheme.primary, colorScheme.secondary, 0.46) ??
                  colorScheme.primary,
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ActivityHistoryLink extends StatelessWidget {
  const _ActivityHistoryLink({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return _ActivityPanelSurface(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.activitiesHistoryTitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.activitiesHistoryHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              );
              final action = _ActivityHistoryActionPill(
                label: l10n.activitiesHistoryButton,
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    copy,
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: action),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 12),
                  SizedBox(width: 190, child: action),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActivityHistoryActionPill extends StatelessWidget {
  const _ActivityHistoryActionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: SizedBox(
        height: 42,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: colorScheme.primary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityPanelSurface extends StatelessWidget {
  const _ActivityPanelSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }
}

class _ActivityStateSurface extends StatelessWidget {
  const _ActivityStateSurface({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
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
  bool _refreshing = false;
  String _error = '';
  String _refreshError = '';
  String _loadMoreError = '';
  String? _loadedQueryGameId;

  @override
  Widget build(BuildContext context) {
    final queryGameId =
        GoRouterState.of(context).uri.queryParameters['game_id'] ?? '';
    final l10n = context.l10n;
    final rightsAccess =
        _activityRightsAccess(ref.watch(authControllerProvider));

    if (_loadedQueryGameId != queryGameId) {
      _loadedQueryGameId = queryGameId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
    }

    return AppShell(
      title: l10n.activitiesHistoryTitle,
      currentPath: '/activities',
      backPath: '/activities',
      child: _ActivitiesPageList(
        children: [
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
                  queryParameters: next.isEmpty ? null : {'game_id': next},
                );
                context.go(uri.toString());
              },
            ),
            const SizedBox(height: 12),
            if (_items.isEmpty)
              const _EmptyHistoryActivitiesCard()
            else ...[
              if (_refreshError.isNotEmpty) ...[
                _ActivityInlineError(message: _refreshError, onRetry: _refresh),
                const SizedBox(height: 12),
              ],
              for (final activity in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ActivityListCard(
                    activity: activity,
                    rightsAccess: rightsAccess,
                    historyGameId: _selectedHistoryGameId(
                      meta: _meta,
                      requestedGameId: queryGameId,
                    ),
                  ),
                ),
            ],
            if (_loadMoreError.isNotEmpty)
              _ActivityInlineError(message: _loadMoreError, onRetry: _loadMore),
            if (_meta.hasMore || _loadingMore)
              _ActivityLoadMoreButton(
                loading: _loadingMore,
                onPressed: _loadMore,
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _refresh() => _load(
        reset: true,
        showLoading: false,
        preserveDataOnError: true,
      );

  Future<void> _loadMore() => _load(reset: false);

  Future<void> _load({
    required bool reset,
    bool showLoading = true,
    bool preserveDataOnError = false,
  }) async {
    if (_loadingMore || (_loading && !reset) || (reset && _refreshing)) return;
    if (!reset && (!_meta.hasMore || (_meta.nextCursor ?? '').isEmpty)) return;

    final gameId = _loadedQueryGameId ?? '';
    if (reset) _refreshing = true;
    final shouldShowBlockingLoading = reset && (showLoading || _items.isEmpty);
    setState(() {
      if (reset) {
        if (shouldShowBlockingLoading) {
          _loading = true;
          _items.clear();
          _meta = ActivityListMeta.empty;
        }
      } else {
        _loadingMore = true;
      }
      _error = '';
      _refreshError = '';
      _loadMoreError = '';
    });

    try {
      final auth = ref.read(authControllerProvider);
      final authenticated =
          _activityRightsAccess(auth) == _ActivityRightsAccess.ready;
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
      final message = activityErrorMessage(
        error,
        context.l10n.activitiesLoadFailed,
      );
      setState(() {
        if (reset) {
          if (preserveDataOnError && _items.isNotEmpty) {
            _refreshError = message;
          } else {
            _error = message;
          }
        } else {
          _loadMoreError = message;
        }
      });
    } finally {
      if (reset) _refreshing = false;
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

enum _ActivityRightsAccess { guest, pin, ready }

_ActivityRightsAccess _activityRightsAccess(AuthController auth) {
  if (!auth.isAuthenticated) return _ActivityRightsAccess.guest;
  if (auth.pinRequired || auth.pinSetupRequired) {
    return _ActivityRightsAccess.pin;
  }
  return _ActivityRightsAccess.ready;
}

bool _hasCurrentActivityRight(ActivityItem activity) {
  if (activity.isCashback) return activity.hasRight;
  if (!activity.isLuckyBoard) return activity.hasRight;
  return !activityEntryClosed(activity) && activity.rights.remainingCount > 0;
}

String _activityRightsState(
  ActivityItem activity, {
  required bool entryClosed,
  required _ActivityRightsAccess access,
}) {
  if (entryClosed) return 'closed';
  if (access == _ActivityRightsAccess.guest) return 'guest';
  if (access == _ActivityRightsAccess.pin) return 'pin';
  if (activity.hasRight || activity.rights.remainingCount > 0) {
    return 'available';
  }
  if (activity.rights.earnedCount > 0 || activity.rights.usedCount > 0) {
    return 'used';
  }
  return 'none';
}

String _activityRightsText(
  CustomerLocalizations l10n,
  ActivityItem activity, {
  required bool entryClosed,
  required _ActivityRightsAccess access,
}) {
  if (entryClosed) return l10n.activityMetaEntryClosed;
  if (access == _ActivityRightsAccess.guest) return l10n.activityMetaGuest;
  if (access == _ActivityRightsAccess.pin) return l10n.activityMetaPin;
  if (activity.isCashback) return activityMetaText(l10n, activity);
  if (activity.rights.remainingCount > 0) {
    return l10n.activityMetaRights(activity.rights.remainingCount);
  }
  if (activity.rights.earnedCount > 0 || activity.rights.usedCount > 0) {
    return l10n.activityMetaRightsUsed;
  }
  return l10n.activityMetaNoRights;
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
    return _ActivityPanelSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 430;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.activitiesHistorySelectLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  selectedLabel ?? l10n.activitiesHistoryTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            );
            final dropdown = DropdownButtonFormField<String>(
              initialValue: games.any((game) => game.id == selectedGameId)
                  ? selectedGameId
                  : null,
              isExpanded: true,
              borderRadius: BorderRadius.circular(18),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.9),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.9),
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.9),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: colorScheme.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                isDense: true,
              ),
              hint: Text(l10n.activitiesHistoryNoGames),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
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
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  copy,
                  const SizedBox(height: 12),
                  dropdown,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 12),
                SizedBox(width: 190, child: dropdown),
              ],
            );
          },
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
    return _ActivityStateSurface(
      children: [
        const ActivityLoadingMark(
          key: Key('activities-loading-mark'),
          size: 46,
        ),
        const SizedBox(height: 12),
        const ActivityProgressLine(
          key: Key('activities-loading-progress'),
          width: 128,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
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
    return _ActivityStateSurface(
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
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.primary,
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          child: Text(context.l10n.commonRetry),
        ),
      ],
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: activityErrorTint(colorScheme),
        border: Border.all(color: activityErrorBorder(colorScheme)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: activityErrorForeground(colorScheme),
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.primary,
                textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: SizedBox(
          width: 160,
          child: OutlinedButton(
            onPressed: loading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(160, 44),
              shape: const StadiumBorder(),
              side: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.9),
              ),
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            child: Text(
              loading
                  ? context.l10n.commonLoadingMore
                  : context.l10n.commonLoadMore,
            ),
          ),
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
    return _ActivityStateSurface(
      children: [
        Icon(
          Icons.card_giftcard,
          size: 38,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.activitiesEmptyTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.activitiesEmptyMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _EmptyHistoryActivitiesCard extends StatelessWidget {
  const _EmptyHistoryActivitiesCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ActivityStateSurface(
      children: [
        Icon(
          Icons.history,
          size: 38,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.activitiesHistoryEmptyTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.activitiesHistoryEmptyMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 230,
          child: FilledButton(
            onPressed: () => context.go('/activities'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              shape: const StadiumBorder(),
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            child: Text(l10n.activitiesBackToCurrent),
          ),
        ),
      ],
    );
  }
}

class _ActivityListCard extends StatelessWidget {
  const _ActivityListCard({
    required this.activity,
    required this.rightsAccess,
    this.historyGameId = '',
  });

  final ActivityItem activity;
  final _ActivityRightsAccess rightsAccess;
  final String historyGameId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final entryClosed = activityEntryClosed(activity);
    final rightsState = _activityRightsState(
      activity,
      entryClosed: entryClosed,
      access: rightsAccess,
    );
    final showDeadlinePill = activity.isLuckyBoard && historyGameId.isEmpty;
    final detailUri = Uri(
      path: '/activities/${activity.slug}',
      queryParameters: historyGameId.isEmpty
          ? null
          : {'from': 'history', 'game_id': historyGameId},
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.70),
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: activity.slug.isEmpty
                ? null
                : () => context.go(detailUri.toString()),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 375;
                final imageWidth = compact
                    ? 94.0
                    : (constraints.maxWidth * 0.28).clamp(98.0, 132.0);
                final minHeight =
                    (constraints.maxWidth * 0.30).clamp(132.0, 154.0);

                return ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: imageWidth,
                          child: activity.imageUrl.isEmpty
                              ? ActivityImageFallback(
                                  isCashback: activity.isCashback,
                                )
                              : Image.network(
                                  activity.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      ActivityImageFallback(
                                    isCashback: activity.isCashback,
                                  ),
                                ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(compact ? 11 : 15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                _ActivityTypeBadge(
                                  label: l10n.activityTypeLabel(activity.type),
                                  compact: compact,
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
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.w900,
                                        height: 1.25,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  activityConditionText(l10n, activity),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                        height: 1.35,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                _ActivityRightsBadge(
                                  label: _activityRightsText(
                                    l10n,
                                    activity,
                                    entryClosed: entryClosed,
                                    access: rightsAccess,
                                  ),
                                  state: rightsState,
                                  compact: compact,
                                ),
                                if (activity.isLuckyBoard) ...[
                                  const SizedBox(height: 6),
                                  _ActivityNumberBadge(
                                    label: l10n.activityMetaRemainingNumbers(
                                      activity.remainingNumbers,
                                    ),
                                    compact: compact,
                                  ),
                                ],
                                if (showDeadlinePill) ...[
                                  const SizedBox(height: 6),
                                  _ActivityDeadlinePill(
                                    label: activityEntryDeadlineText(
                                      l10n,
                                      activity,
                                    ),
                                    closed: entryClosed,
                                    compact: compact,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityNumberBadge extends StatelessWidget {
  const _ActivityNumberBadge({
    required this.label,
    required this.compact,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Flexible(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.40),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.88),
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 28),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityDeadlinePill extends StatelessWidget {
  const _ActivityDeadlinePill({
    required this.label,
    required this.closed,
    required this.compact,
  });

  final String label;
  final bool closed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = closed
        ? activityErrorTint(colorScheme)
        : activityWarningTint(colorScheme);
    final border = closed
        ? activityErrorBorder(colorScheme)
        : activityWarningBorder(colorScheme);
    final foreground = closed
        ? activityErrorForeground(colorScheme)
        : activityWarningForeground(colorScheme);

    return Row(
      children: [
        Flexible(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(999),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 28),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, color: foreground, size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: foreground,
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityTypeBadge extends StatelessWidget {
  const _ActivityTypeBadge({
    required this.label,
    required this.compact,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
          ),
        ),
      ),
    );
  }
}

class _ActivityRightsBadge extends StatelessWidget {
  const _ActivityRightsBadge({
    required this.label,
    required this.state,
    required this.compact,
  });

  final String label;
  final String state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = switch (state) {
      'available' => (
          background: activitySuccessTint(colorScheme),
          foreground: activitySuccessForeground(colorScheme),
          icon: Icons.check_circle,
        ),
      'used' => (
          background: activityInfoTint(colorScheme),
          foreground: activityInfoForeground(colorScheme),
          icon: Icons.check_circle_outline,
        ),
      'closed' => (
          background: activityErrorTint(colorScheme),
          foreground: activityErrorForeground(colorScheme),
          icon: Icons.access_time_filled,
        ),
      'guest' || 'pin' => (
          background: colorScheme.surfaceContainerHighest,
          foreground: colorScheme.onSurfaceVariant,
          icon: Icons.lock,
        ),
      _ => (
          background: colorScheme.surfaceContainerHighest,
          foreground: colorScheme.onSurfaceVariant,
          icon: Icons.info,
        ),
    };
    return Row(
      children: [
        Flexible(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(999),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 25),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(colors.icon, color: colors.foreground, size: 14),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colors.foreground,
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
