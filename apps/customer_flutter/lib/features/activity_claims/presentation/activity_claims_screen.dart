import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/activity_claim_models.dart';
import '../data/activity_claim_repository.dart';
import '../../reward_claims/presentation/claim_realtime_monitor.dart';
import 'activity_claim_error_message.dart';
import 'activity_claim_localization.dart';

Color _activityClaimPrimaryTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.primary, colorScheme.surface, 0.88) ??
    colorScheme.primary.withValues(alpha: 0.12);

class ActivityClaimsScreen extends ConsumerStatefulWidget {
  const ActivityClaimsScreen({super.key});

  @override
  ConsumerState<ActivityClaimsScreen> createState() =>
      _ActivityClaimsScreenState();
}

class _ActivityClaimsScreenState extends ConsumerState<ActivityClaimsScreen> {
  final _claims = <ActivityClaimItem>[];
  String? _cursor;
  bool _hasMore = false;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _refreshingInitial = false;
  String _error = '';
  String _refreshError = '';
  String _loadMoreError = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadInitial);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen<int>(
      activityClaimRealtimeTickProvider,
      (_, __) => _scheduleRealtimeRefresh(),
    );
    return AppShell(
      title: l10n.activityClaimsTitle,
      currentPath: '/profile',
      backPath: '/profile',
      sensitive: true,
      showBottomNavigation: false,
      compactHeader: true,
      child: RefreshIndicator(
        onRefresh: () => _loadInitial(
          showLoading: false,
          preserveDataOnError: true,
        ),
        child: _ActivityClaimsPageBody(
          child: _loadingInitial
              ? const _ActivityClaimsLoading()
              : _error.isNotEmpty
                  ? _ActivityClaimsError(
                      message: _error,
                      onRetry: () => _loadInitial(
                        showLoading: true,
                        preserveDataOnError: false,
                      ),
                    )
                  : _claims.isEmpty
                      ? _ActivityClaimsEmpty(
                          onActivities: () => context.go('/activities'),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_refreshError.isNotEmpty)
                              _ActivityClaimsInlineError(
                                message: _refreshError,
                                onRetry: () => _loadInitial(
                                  showLoading: false,
                                  preserveDataOnError: true,
                                ),
                              ),
                            for (var index = 0; index < _claims.length; index++)
                              _ActivityClaimTile(
                                claim: _claims[index],
                                showDivider: index < _claims.length - 1,
                                onTap: () => context.go(
                                  '/activity-claims/${_claims[index].id}',
                                ),
                              ),
                            if (_loadMoreError.isNotEmpty)
                              _ActivityClaimsInlineError(
                                message: _loadMoreError,
                                onRetry: _loadMore,
                              ),
                            if (_hasMore)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Align(
                                  child: OutlinedButton(
                                    style: _claimOutlinePillStyle(context),
                                    onPressed: _loadingMore ? null : _loadMore,
                                    child: Text(
                                      _loadingMore
                                          ? l10n.commonLoadingMore
                                          : l10n.commonLoadMore,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
        ),
      ),
    );
  }

  void _scheduleRealtimeRefresh() {
    if (!mounted || _loadingInitial || _loadingMore || _refreshingInitial) {
      return;
    }
    Future.microtask(() {
      if (mounted && !_loadingInitial && !_loadingMore) {
        _loadInitial(
          showLoading: false,
          preserveDataOnError: true,
        );
      }
    });
  }

  Future<void> _loadInitial({
    bool showLoading = true,
    bool preserveDataOnError = false,
  }) async {
    if (_refreshingInitial) return;
    _refreshingInitial = true;
    final shouldShowBlockingLoading = showLoading || _claims.isEmpty;
    setState(() {
      if (shouldShowBlockingLoading) _loadingInitial = true;
      _error = '';
      _refreshError = '';
      _loadMoreError = '';
    });
    try {
      final page = await ref.read(activityClaimRepositoryProvider).list();
      if (!mounted) return;
      setState(() {
        _claims
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      final message = activityClaimErrorMessage(
        error,
        context.l10n.activityClaimsLoadFailed,
      );
      setState(
        () {
          if (preserveDataOnError && _claims.isNotEmpty) {
            _refreshError = message;
          } else {
            _error = message;
          }
        },
      );
    } finally {
      _refreshingInitial = false;
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || cursor.isEmpty || _loadingMore) return;

    setState(() {
      _loadingMore = true;
      _refreshError = '';
      _loadMoreError = '';
    });
    try {
      final page =
          await ref.read(activityClaimRepositoryProvider).list(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _claims.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loadMoreError = '';
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _loadMoreError = activityClaimErrorMessage(
            error,
            context.l10n.activityClaimsLoadMoreFailed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }
}

class _ActivityClaimsPageBody extends StatelessWidget {
  const _ActivityClaimsPageBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: CustomerPageBody(
                  maxWidth: 640,
                  top: 0,
                  bottom: 22,
                  mobileHorizontal: 0,
                  wideHorizontal: 0,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActivityClaimTile extends StatelessWidget {
  const _ActivityClaimTile({
    required this.claim,
    required this.onTap,
    required this.showDivider,
  });

  final ActivityClaimItem claim;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, claim);
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: showDivider
                ? Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ActivityClaimRowLine(
                  leading: Text(
                    l10n.activityClaimsPrizeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  trailing: Text(
                    formatBaht(claim.amount),
                    textAlign: TextAlign.right,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                _ActivityClaimRowLine(
                  leading: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizedActivityClaimRewardLabel(context, claim),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 15,
                          height: 1.32,
                        ),
                      ),
                      Text(
                        localizedActivityClaimActivityName(context, claim),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 15,
                          height: 1.32,
                        ),
                      ),
                    ],
                  ),
                  trailing: _StatusChip(
                    label: localizedActivityClaimStatusLabel(context, claim),
                    color: color,
                    backgroundColor: _statusBackgroundColor(context, claim),
                  ),
                  trailingMaxWidthFactor: 0.56,
                ),
                const SizedBox(height: 3),
                Text(
                  localizedActivityClaimPayoutSummary(context, claim),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 15,
                    height: 1.32,
                  ),
                ),
                const SizedBox(height: 3),
                _ActivityClaimRowLine(
                  leading: Text(
                    localizedActivityClaimSubmittedAt(context, claim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.72,
                      ),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1.32,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colorScheme.primary,
                    size: 23,
                  ),
                  trailingMaxWidthFactor: 0.2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityClaimRowLine extends StatelessWidget {
  const _ActivityClaimRowLine({
    required this.leading,
    required this.trailing,
    this.trailingMaxWidthFactor = 0.46,
  });

  final Widget leading;
  final Widget trailing;
  final double trailingMaxWidthFactor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: leading),
            const SizedBox(width: 10),
            Flexible(
              flex: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * trailingMaxWidthFactor,
                ),
                child: trailing,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: backgroundColor,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
      ),
    );
  }
}

class _ActivityClaimsEmpty extends StatelessWidget {
  const _ActivityClaimsEmpty({required this.onActivities});

  final VoidCallback onActivities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 54),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _activityClaimPrimaryTint(colorScheme),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_giftcard_outlined,
              size: 30,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.activityClaimsEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.activityClaimsEmptySubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _ActivityClaimsPrimaryPill(
            label: l10n.activityClaimsViewActivities,
            onPressed: onActivities,
          ),
        ],
      ),
    );
  }
}

class _ActivityClaimsPrimaryPill extends StatelessWidget {
  const _ActivityClaimsPrimaryPill({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(999);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 190, minHeight: 47),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color.lerp(colorScheme.primary, colorScheme.secondary, 0.18) ??
                  colorScheme.primary,
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
            borderRadius: radius,
            onTap: onPressed,
            child: SizedBox(
              height: 47,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimary,
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
      ),
    );
  }
}

class _ActivityClaimsLoading extends StatelessWidget {
  const _ActivityClaimsLoading();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _ActivityClaimsStatePanel(
      child: Text(
        context.l10n.activityClaimsLoading,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
      ),
    );
  }
}

class _ActivityClaimsError extends StatelessWidget {
  const _ActivityClaimsError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _ActivityClaimsStatePanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            style: _claimOutlinePillStyle(context),
            onPressed: onRetry,
            child: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}

class _ActivityClaimsInlineError extends StatelessWidget {
  const _ActivityClaimsInlineError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final messageText = Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
          );
          final retryButton = OutlinedButton(
            style: _claimOutlinePillStyle(context).copyWith(
              minimumSize: WidgetStateProperty.all(const Size(108, 40)),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
            onPressed: onRetry,
            child: Text(context.l10n.commonRetry),
          );
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.46),
              border: Border.all(
                color: colorScheme.error.withValues(alpha: 0.22),
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: constraints.maxWidth < 360
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: messageText),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(child: retryButton),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: messageText),
                        const SizedBox(width: 10),
                        retryButton,
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _ActivityClaimsStatePanel extends StatelessWidget {
  const _ActivityClaimsStatePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 52),
      child: Center(child: child),
    );
  }
}

Color _statusColor(BuildContext context, ActivityClaimItem claim) {
  final colorScheme = Theme.of(context).colorScheme;
  if (claim.isPaid) {
    return Color.lerp(colorScheme.tertiary, colorScheme.primary, 0.12) ??
        colorScheme.tertiary;
  }
  if (claim.isRejected) return colorScheme.error;
  return Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.32) ??
      colorScheme.primary;
}

Color _statusBackgroundColor(BuildContext context, ActivityClaimItem claim) {
  final colorScheme = Theme.of(context).colorScheme;
  final statusColor = _statusColor(context, claim);
  final alpha = claim.isRejected ? 0.10 : 0.13;
  return Color.lerp(colorScheme.surface, statusColor, alpha) ??
      statusColor.withValues(alpha: alpha);
}

ButtonStyle _claimOutlinePillStyle(BuildContext context) {
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
