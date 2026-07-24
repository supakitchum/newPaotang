import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/activity_models.dart';
import '../data/activity_repository.dart';
import 'activity_error_message.dart';
import 'activity_localization.dart';
import 'activity_visual_tokens.dart';

const _activitiesSurface = Color(0xFFFFFFFF);
const _activitiesPanelBorder = Color(0xFFE8EEF7);
const _activitiesCardBorder = Color(0xFFEDF1F7);
const _activitiesPanelShadow = Color(0x14083068);
const _activitiesCardShadow = Color(0x1A083068);
const _activitiesMutedText = Color(0xFF94A3B8);
const _activitiesPanelTitle = Color(0xFF1F2F54);
const _activitiesCardTitle = Color(0xFF1F2937);
const _activitiesBodyText = Color(0xFF6B7280);
const _activitiesSecondaryText = Color(0xFF64748B);
const _activitiesSuccessBackground = Color(0xFFDCFCE7);
const _activitiesSuccessText = Color(0xFF15803D);
const _activitiesUsedBackground = Color(0xFFEEF2FF);
const _activitiesUsedText = Color(0xFF3157C8);
const _activitiesNeutralBackground = Color(0xFFF1F5F9);
const _activitiesNumberBackground = Color(0xFFF8FAFC);
const _activitiesNumberBorder = Color(0xFFDBE6F3);
const _activitiesNumberText = Color(0xFF475569);
const _activitiesDeadlineBackground = Color(0xFFFFF7ED);
const _activitiesDeadlineBorder = Color(0xFFFED7AA);
const _activitiesDeadlineText = Color(0xFFC2410C);
const _activitiesClosedBackground = Color(0xFFFEF2F2);
const _activitiesClosedBadgeBackground = Color(0xFFFEE2E2);
const _activitiesClosedBorder = Color(0xFFFECACA);
const _activitiesClosedText = Color(0xFFB42318);
const _activitiesOutlineDisabledBorder = Color(0xFFCBD4DF);
const _activitiesOutlineDisabledText = Color(0xFF8A8F98);
const _activitiesOutlineDisabledBackground = Color(0xFFF2F4F7);
const _activitiesFilterBackground = Color(0xFFF0F6FC);
const _activitiesFilterShadow = Color(0x12083068);
const _activitiesPageBackground = Color(0xFFF4F7FB);

Color _activitiesBrandColor(BuildContext context) {
  return AppTheme.primaryOutlineBorder(Theme.of(context).colorScheme.primary);
}

Color _activitiesActionFill(BuildContext context) {
  return activityBrandActionFill(Theme.of(context).colorScheme);
}

Color _activitiesActionForeground(BuildContext context) {
  return activityBrandActionForeground(Theme.of(context).colorScheme);
}

enum _ActivityBrowseFilter { all, luckyBoard, cashback }

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  final List<ActivityItem> _items = [];
  ActivityListMeta _meta = ActivityListMeta.empty;
  int _requestGeneration = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  String _error = '';
  String _refreshError = '';
  String _loadMoreError = '';
  _ActivityBrowseFilter _filter = _ActivityBrowseFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rightsAccess = _activityRightsAccess(
      ref.watch(authControllerProvider),
    );
    final visibleItems = _filteredActivities(_items, _filter);
    ref.listen<_ActivityRightsAccess>(
      authControllerProvider.select(_activityRightsAccess),
      (previous, next) {
        if (previous == null || previous == next) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _load(reset: true);
        });
      },
    );

    return AppShell(
      title: l10n.homeActivities,
      currentPath: '/activities',
      backPath: '/',
      showBottomNavigation: true,
      heroMinHeight: _ActivitiesPageList.heroMinHeight,
      heroSheetOverlap: _ActivitiesPageList.sheetOverlap,
      heroSheetTopRadius: 26,
      heroContent: const SizedBox.shrink(),
      child: _ActivitiesPageList(
        children: [
          if (_loading)
            _ActivityLoadingCard(message: l10n.activitiesLoading)
          else if (_error.isNotEmpty && _items.isEmpty)
            _ActivityErrorCard(message: _error, onRetry: _refresh)
          else ...[
            if (_meta.hasHistory) ...[
              _ActivityHistoryLink(
                onPressed: () => context.push('/activities/history'),
              ),
              const SizedBox(height: 18),
            ],
            if (_items.isEmpty)
              const _EmptyActivitiesCard()
            else ...[
              _ActivityBrowseToolbar(
                count: visibleItems.length,
                selected: _filter,
                available: _availableActivityFilters(_items),
                onSelected: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 20),
              _ActivityCardsRail(
                children: [
                  if (_refreshError.isNotEmpty)
                    _ActivityInlineError(
                      message: _refreshError,
                      onRetry: _refresh,
                    ),
                  for (final activity in visibleItems)
                    _ActivityListCard(
                      activity: activity,
                      rightsAccess: rightsAccess,
                    ),
                  if (_loadMoreError.isNotEmpty)
                    _ActivityInlineError(
                      message: _loadMoreError,
                      onRetry: _loadMore,
                    ),
                  if (_meta.hasMore || _loadingMore)
                    _ActivityLoadMoreButton(
                      loading: _loadingMore,
                      onPressed: _loadMore,
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _refresh() =>
      _load(reset: true, showLoading: false, preserveDataOnError: true);

  Future<void> _loadMore() => _load(reset: false);

  Future<void> _load({
    required bool reset,
    bool showLoading = true,
    bool preserveDataOnError = false,
  }) async {
    if (!reset && (_loadingMore || _loading || _refreshing)) return;
    if (!reset && (!_meta.hasMore || (_meta.nextCursor ?? '').isEmpty)) return;

    if (_redirectToActivityPinIfNeeded(
      context,
      ref.read(authControllerProvider),
    )) {
      return;
    }

    final requestGeneration = ++_requestGeneration;
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
      final page = await ref
          .read(activityRepositoryProvider)
          .listPage(
            authenticated: authenticated,
            cursor: reset ? '' : (_meta.nextCursor ?? ''),
          );
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() {
        final mergedItems = reset
            ? page.items
            : <ActivityItem>[..._items, ...page.items];
        final sortedItems = _sortActivitiesByRights(
          mergedItems,
          authenticated: authenticated,
        );
        _items
          ..clear()
          ..addAll(sortedItems);
        if (reset && !_activityMatchesFilter(sortedItems, _filter)) {
          _filter = _ActivityBrowseFilter.all;
        }
        _meta = page.meta;
      });
    } catch (error) {
      if (!mounted || requestGeneration != _requestGeneration) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      if (!mounted || requestGeneration != _requestGeneration) return;
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
      if (mounted && requestGeneration == _requestGeneration) {
        if (reset) _refreshing = false;
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

  static const heroMinHeight = customerReferenceCompactHeroHeight;
  static const sheetOverlap = 0.0;
  static const _bottomPadding = 136.0;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final mobileHorizontal = (viewportWidth * 0.045).clamp(16.0, 20.0);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: _activitiesPageBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: CustomerPageBody(
            top: 22,
            bottom: _bottomPadding,
            mobileHorizontal: mobileHorizontal,
            wideHorizontal: 0,
            minViewportHeight: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityBrowseToolbar extends StatelessWidget {
  const _ActivityBrowseToolbar({
    required this.count,
    required this.selected,
    required this.available,
    required this.onSelected,
  });

  final int count;
  final _ActivityBrowseFilter selected;
  final List<_ActivityBrowseFilter> available;
  final ValueChanged<_ActivityBrowseFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            l10n.activitiesBrowseCount(count),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: _activitiesPanelTitle,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 9),
        DecoratedBox(
          decoration: BoxDecoration(
            color: _activitiesFilterBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                for (var index = 0; index < available.length; index++) ...[
                  Expanded(
                    child: _ActivityBrowseSegment(
                      filter: available[index],
                      selected: available[index] == selected,
                      onPressed: () => onSelected(available[index]),
                    ),
                  ),
                  if (index < available.length - 1) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityBrowseSegment extends StatelessWidget {
  const _ActivityBrowseSegment({
    required this.filter,
    required this.selected,
    required this.onPressed,
  });

  final _ActivityBrowseFilter filter;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (filter) {
      _ActivityBrowseFilter.all => l10n.activitiesFilterAll,
      _ActivityBrowseFilter.luckyBoard => l10n.activitiesFilterLucky,
      _ActivityBrowseFilter.cashback => l10n.activitiesFilterCashback,
    };
    final icon = switch (filter) {
      _ActivityBrowseFilter.all => Icons.dashboard_outlined,
      _ActivityBrowseFilter.luckyBoard => Icons.grid_view_rounded,
      _ActivityBrowseFilter.cashback => Icons.account_balance_wallet_outlined,
    };
    final foreground = selected
        ? _activitiesActionForeground(context)
        : _activitiesSecondaryText;
    final radius = BorderRadius.circular(11);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? _activitiesSurface : Colors.transparent,
              borderRadius: radius,
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: _activitiesFilterShadow,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showIcon = constraints.maxWidth >= 92;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showIcon) ...[
                      Icon(icon, color: foreground, size: 17),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: foreground,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

List<_ActivityBrowseFilter> _availableActivityFilters(
  List<ActivityItem> items,
) {
  return [
    _ActivityBrowseFilter.all,
    if (items.any((item) => item.isLuckyBoard))
      _ActivityBrowseFilter.luckyBoard,
    if (items.any((item) => item.isCashback)) _ActivityBrowseFilter.cashback,
  ];
}

List<ActivityItem> _filteredActivities(
  List<ActivityItem> items,
  _ActivityBrowseFilter filter,
) {
  if (filter == _ActivityBrowseFilter.all) return items;
  return items
      .where((item) => _activityMatchesBrowseFilter(item, filter))
      .toList(growable: false);
}

bool _activityMatchesFilter(
  List<ActivityItem> items,
  _ActivityBrowseFilter filter,
) {
  return filter == _ActivityBrowseFilter.all ||
      items.any((item) => _activityMatchesBrowseFilter(item, filter));
}

bool _activityMatchesBrowseFilter(
  ActivityItem item,
  _ActivityBrowseFilter filter,
) {
  return switch (filter) {
    _ActivityBrowseFilter.all => true,
    _ActivityBrowseFilter.luckyBoard => item.isLuckyBoard,
    _ActivityBrowseFilter.cashback => item.isCashback,
  };
}

class _ActivityHistoryLink extends StatelessWidget {
  const _ActivityHistoryLink({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ActivityPanelSurface(
      child: InkWell(
        onTap: onPressed,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = MediaQuery.sizeOf(context).width < 576;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.activitiesHistoryTitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _activitiesMutedText,
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
                      color: _activitiesPanelTitle,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _activitiesActionFill(context),
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
                    color: _activitiesActionForeground(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: _activitiesActionForeground(context),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _activitiesSurface,
        border: Border.all(color: _activitiesPanelBorder),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _activitiesPanelShadow,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _activitiesSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _activitiesCardShadow,
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
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
  int _requestGeneration = 0;
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
    final rightsAccess = _activityRightsAccess(
      ref.watch(authControllerProvider),
    );
    ref.listen<_ActivityRightsAccess>(
      authControllerProvider.select(_activityRightsAccess),
      (previous, next) {
        if (previous == null || previous == next) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _load(reset: true);
        });
      },
    );

    if (_loadedQueryGameId != queryGameId) {
      _loadedQueryGameId = queryGameId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
    }

    return AppShell(
      title: l10n.activitiesHistoryTitle,
      currentPath: '/activities',
      backPath: '/activities',
      showBottomNavigation: true,
      heroMinHeight: _ActivitiesPageList.heroMinHeight,
      heroSheetOverlap: _ActivitiesPageList.sheetOverlap,
      heroSheetTopRadius: 26,
      heroContent: const SizedBox.shrink(),
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
            else
              _ActivityCardsRail(
                children: [
                  if (_refreshError.isNotEmpty)
                    _ActivityInlineError(
                      message: _refreshError,
                      onRetry: _refresh,
                    ),
                  for (final activity in _items)
                    _ActivityListCard(
                      activity: activity,
                      rightsAccess: rightsAccess,
                      historyGameId: _selectedHistoryGameId(
                        meta: _meta,
                        requestedGameId: queryGameId,
                      ),
                      history: true,
                    ),
                  if (_loadMoreError.isNotEmpty)
                    _ActivityInlineError(
                      message: _loadMoreError,
                      onRetry: _loadMore,
                    ),
                  if (_meta.hasMore || _loadingMore)
                    _ActivityLoadMoreButton(
                      loading: _loadingMore,
                      onPressed: _loadMore,
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _refresh() =>
      _load(reset: true, showLoading: false, preserveDataOnError: true);

  Future<void> _loadMore() => _load(reset: false);

  Future<void> _load({
    required bool reset,
    bool showLoading = true,
    bool preserveDataOnError = false,
  }) async {
    if (!reset && (_loadingMore || _loading || _refreshing)) return;
    if (!reset && (!_meta.hasMore || (_meta.nextCursor ?? '').isEmpty)) return;

    if (_redirectToActivityPinIfNeeded(
      context,
      ref.read(authControllerProvider),
    )) {
      return;
    }

    final requestGeneration = ++_requestGeneration;
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
      final page = await ref
          .read(activityRepositoryProvider)
          .listPage(
            authenticated: authenticated,
            history: true,
            gameId: gameId,
            cursor: reset ? '' : (_meta.nextCursor ?? ''),
          );
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() {
        final mergedItems = reset
            ? page.items
            : <ActivityItem>[..._items, ...page.items];
        final sortedItems = _sortActivitiesByRights(
          mergedItems,
          authenticated: authenticated,
          history: true,
        );
        _items
          ..clear()
          ..addAll(sortedItems);
        _meta = page.meta;
      });
    } catch (error) {
      if (!mounted || requestGeneration != _requestGeneration) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      if (!mounted || requestGeneration != _requestGeneration) return;
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
      if (mounted && requestGeneration == _requestGeneration) {
        if (reset) _refreshing = false;
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }
}

class _ActivityCardsRail extends StatelessWidget {
  const _ActivityCardsRail({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final gap = (viewportWidth * 0.045).clamp(16.0, 20.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 680;
        if (!twoColumns) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1) SizedBox(height: gap),
              ],
            ],
          );
        }

        final itemWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(
                width:
                    child is _ActivityInlineError ||
                        child is _ActivityLoadMoreButton
                    ? constraints.maxWidth
                    : itemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

List<ActivityItem> _sortActivitiesByRights(
  List<ActivityItem> items, {
  required bool authenticated,
  bool history = false,
}) {
  if (!authenticated) return items;

  final indexed = [
    for (var index = 0; index < items.length; index++)
      MapEntry(index, items[index]),
  ];
  indexed.sort((first, second) {
    final firstHasRight = _hasActivityRightForSort(
      first.value,
      history: history,
    );
    final secondHasRight = _hasActivityRightForSort(
      second.value,
      history: history,
    );
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

bool _redirectToActivityPinIfNeeded(BuildContext context, AuthController auth) {
  if (_activityRightsAccess(auth) != _ActivityRightsAccess.pin) return false;

  final redirect = GoRouterState.of(context).uri.toString();
  context.go(
    Uri(path: '/pin', queryParameters: {'redirect': redirect}).toString(),
  );
  return true;
}

bool _hasActivityRightForSort(ActivityItem activity, {required bool history}) {
  if (activity.isCashback) return activity.hasRight;
  if (!activity.isLuckyBoard) return activity.hasRight;
  return (history || !activityEntryClosed(activity)) &&
      activity.rights.remainingCount > 0;
}

String _activityRightsState(
  ActivityItem activity, {
  required bool entryClosed,
  required _ActivityRightsAccess access,
}) {
  if (entryClosed) return 'closed';
  if (access == _ActivityRightsAccess.guest) return 'guest';
  if (access == _ActivityRightsAccess.pin) return 'pin';
  if (activity.isCashback && activity.hasRight) {
    return 'available';
  }
  if (activity.isLuckyBoard && activity.rights.remainingCount > 0) {
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
    final selectedLabel = games
        .where((game) => game.id == selectedGameId)
        .map((game) => game.label)
        .firstOrNull;
    return _ActivityPanelSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = MediaQuery.sizeOf(context).width < 576;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.activitiesHistorySelectLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _activitiesMutedText,
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
                    color: _activitiesPanelTitle,
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
                  borderSide: BorderSide(color: _activitiesNumberBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: _activitiesNumberBorder),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: _activitiesNumberBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: _activitiesBrandColor(context)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                isDense: true,
              ),
              hint: Text(l10n.activitiesHistoryNoGames),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: _activitiesPanelTitle,
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
                children: [copy, const SizedBox(height: 12), dropdown],
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
  const _ActivityErrorCard({required this.message, required this.onRetry});

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
            textStyle: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          child: Text(context.l10n.commonRetry),
        ),
      ],
    );
  }
}

class _ActivityInlineError extends StatelessWidget {
  const _ActivityInlineError({required this.message, required this.onRetry});

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
                textStyle: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
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
            style:
                OutlinedButton.styleFrom(
                  backgroundColor: _activitiesSurface,
                  disabledBackgroundColor: _activitiesOutlineDisabledBackground,
                  disabledForegroundColor: _activitiesOutlineDisabledText,
                  foregroundColor: AppTheme.primaryOutlineText(
                    Theme.of(context).colorScheme.primary,
                  ),
                  minimumSize: const Size(160, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ).copyWith(
                  side: WidgetStateProperty.resolveWith(
                    (states) => BorderSide(
                      color: states.contains(WidgetState.disabled)
                          ? _activitiesOutlineDisabledBorder
                          : AppTheme.primaryOutlineBorder(
                              Theme.of(context).colorScheme.primary,
                            ),
                    ),
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
          color: _activitiesBrandColor(context),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.activitiesEmptyTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _activitiesCardTitle,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.activitiesEmptyMessage,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: _activitiesSecondaryText),
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
        Icon(Icons.history, size: 38, color: _activitiesBrandColor(context)),
        const SizedBox(height: 12),
        Text(
          l10n.activitiesHistoryEmptyTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _activitiesCardTitle,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.activitiesHistoryEmptyMessage,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: _activitiesSecondaryText),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 230,
          child: _ActivityCurrentLinkPill(
            onPressed: () => context.go('/activities'),
            label: l10n.activitiesBackToCurrent,
          ),
        ),
      ],
    );
  }
}

class _ActivityCurrentLinkPill extends StatelessWidget {
  const _ActivityCurrentLinkPill({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _activitiesBrandColor(context),
        borderRadius: radius,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          onTap: onPressed,
          child: SizedBox(
            height: 42,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
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

class _ActivityListCard extends StatelessWidget {
  const _ActivityListCard({
    required this.activity,
    required this.rightsAccess,
    this.historyGameId = '',
    this.history = false,
  });

  final ActivityItem activity;
  final _ActivityRightsAccess rightsAccess;
  final String historyGameId;
  final bool history;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entryClosed = !history && activityEntryClosed(activity);
    final rightsState = _activityRightsState(
      activity,
      entryClosed: entryClosed,
      access: rightsAccess,
    );
    final showDeadlinePill = activity.isLuckyBoard && !history;
    final detailUri = Uri(
      path: '/activities/${activity.slug}',
      queryParameters: historyGameId.isEmpty
          ? null
          : {'from': 'history', 'game_id': historyGameId},
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _activitiesSurface,
        border: Border.all(color: _activitiesCardBorder),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _activitiesCardShadow,
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
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            onTap: activity.slug.isEmpty
                ? null
                : () => context.push(detailUri.toString()),
            child: LayoutBuilder(
              builder: (context, _) {
                final viewportWidth = MediaQuery.sizeOf(context).width;
                final compact = viewportWidth < 375;
                final bodyPadding = compact ? 14.0 : 16.0;
                const bodyGap = 8.0;
                final artwork = activity.imageUrl.isEmpty
                    ? ActivityImageFallback(isCashback: activity.isCashback)
                    : Image.network(
                        activity.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ActivityImageFallback(
                          isCashback: activity.isCashback,
                        ),
                      );
                final body = Padding(
                  padding: EdgeInsets.all(bodyPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _ActivityTypeBadge(
                            label: l10n.activityTypeLabel(activity.type),
                            compact: compact,
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right,
                            color: _activitiesActionForeground(context),
                            size: 23,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        activityDisplayName(l10n, activity),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: _activitiesCardTitle,
                              fontSize: compact ? 17 : 18,
                              fontWeight: FontWeight.w900,
                              height: 1.3,
                            ),
                      ),
                      const SizedBox(height: bodyGap),
                      Text(
                        activityConditionText(l10n, activity),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _activitiesBodyText,
                          fontSize: compact ? 13 : 14,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                        const SizedBox(height: bodyGap),
                        _ActivityNumberBadge(
                          label: l10n.activityMetaRemainingNumbers(
                            activity.remainingNumbers,
                          ),
                          compact: compact,
                        ),
                      ],
                      if (showDeadlinePill) ...[
                        const SizedBox(height: bodyGap),
                        _ActivityDeadlinePill(
                          label: activityEntryDeadlineText(l10n, activity),
                          closed: entryClosed,
                          compact: compact,
                        ),
                      ],
                    ],
                  ),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      key: Key('activity-card-artwork-${activity.id}'),
                      aspectRatio: 16 / 9,
                      child: artwork,
                    ),
                    body,
                  ],
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
  const _ActivityNumberBadge({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _activitiesNumberBackground,
              border: Border.all(color: _activitiesNumberBorder),
              borderRadius: BorderRadius.circular(999),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      color: _activitiesNumberText,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _activitiesNumberText,
                          fontSize: compact ? 12 : 13,
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
    final background = closed
        ? _activitiesClosedBackground
        : _activitiesDeadlineBackground;
    final border = closed ? _activitiesClosedBorder : _activitiesDeadlineBorder;
    final foreground = closed ? _activitiesClosedText : _activitiesDeadlineText;

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
              constraints: const BoxConstraints(minHeight: 32),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, color: foreground, size: 15),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: foreground,
                          fontSize: compact ? 12 : 13,
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
  const _ActivityTypeBadge({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _activitiesActionFill(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 27),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _activitiesActionForeground(context),
              fontSize: compact ? 12 : 13,
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
    final colors = switch (state) {
      'available' => (
        background: _activitiesSuccessBackground,
        foreground: _activitiesSuccessText,
        icon: Icons.check_circle,
      ),
      'used' => (
        background: _activitiesUsedBackground,
        foreground: _activitiesUsedText,
        icon: Icons.check_circle_outline,
      ),
      'closed' => (
        background: _activitiesClosedBadgeBackground,
        foreground: _activitiesClosedText,
        icon: Icons.access_time_filled,
      ),
      'guest' || 'pin' => (
        background: _activitiesNeutralBackground,
        foreground: _activitiesSecondaryText,
        icon: Icons.lock,
      ),
      _ => (
        background: _activitiesNeutralBackground,
        foreground: _activitiesSecondaryText,
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
              constraints: const BoxConstraints(minHeight: 28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(colors.icon, color: colors.foreground, size: 15),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.foreground,
                          fontSize: compact ? 12 : 13,
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
