import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/activity_claim_models.dart';
import '../data/activity_claim_repository.dart';
import '../../reward_claims/presentation/claim_realtime_monitor.dart';
import 'activity_claim_error_message.dart';
import 'activity_claim_localization.dart';

const _activityClaimHeadTextColor = Color(0xFF202938);
const _activityClaimBodyTextColor = Color(0xFF4B5563);
const _activityClaimMutedTextColor = Color(0xFF94A3B8);
const _activityClaimDividerColor = Color(0xFFEEF2F7);
const _activityClaimEmptyIconBackground = Color(0xFFEEF7FF);
const _activityClaimEmptyTitleColor = Color(0xFF111827);
const _activityClaimEmptyTextColor = Color(0xFF64748B);
const _activityClaimPaidColor = Color(0xFF28A81E);
const _activityClaimPaidBackground = Color(0xFFE5F8DF);
const _activityClaimPendingColor = Color(0xFFE29300);
const _activityClaimPendingBackground = Color(0xFFFFF3D0);
const _activityClaimRejectedColor = Color(0xFFED2C25);
const _activityClaimRejectedBackground = Color(0xFFFFE1DF);
const _activityClaimOutlineDisabledBorder = Color(0xFFCBD4DF);
const _activityClaimOutlineDisabledText = Color(0xFF8A8F98);
const _activityClaimOutlineDisabledBackground = Color(0xFFF2F4F7);

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
      heroContent: const SizedBox.shrink(),
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      child: _ActivityClaimsPageBody(
        child: _loadingInitial
            ? const _ActivityClaimsLoading()
            : _error.isNotEmpty
            ? _ActivityClaimsError(
                message: _error,
                onRetry: () =>
                    _loadInitial(showLoading: true, preserveDataOnError: false),
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
                      onTap: () =>
                          context.go('/activity-claims/${_claims[index].id}'),
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
    );
  }

  void _scheduleRealtimeRefresh() {
    if (!mounted || _loadingInitial || _loadingMore || _refreshingInitial) {
      return;
    }
    Future.microtask(() {
      if (mounted && !_loadingInitial && !_loadingMore) {
        _loadInitial(showLoading: false, preserveDataOnError: true);
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
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      if (!mounted) return;
      final message = activityClaimErrorMessage(
        error,
        context.l10n.activityClaimsLoadFailed,
      );
      setState(() {
        if (preserveDataOnError && _claims.isNotEmpty) {
          _refreshError = message;
        } else {
          _error = message;
        }
      });
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
      final page = await ref
          .read(activityClaimRepositoryProvider)
          .list(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _claims.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loadMoreError = '';
      });
    } catch (error) {
      if (!mounted) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      if (!mounted) return;
      setState(
        () => _loadMoreError = activityClaimErrorMessage(
          error,
          context.l10n.activityClaimsLoadMoreFailed,
        ),
      );
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
                color: Colors.white,
                child: CustomerPageBody(
                  maxWidth: 640,
                  top: 0,
                  bottom: 22,
                  mobileHorizontal: 0,
                  wideHorizontal: 0,
                  minViewportHeight: true,
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
  const _ActivityClaimTile({required this.claim, required this.onTap});

  final ActivityClaimItem claim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(claim);
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      child: InkWell(
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _activityClaimDividerColor),
            ),
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
                      color: _activityClaimHeadTextColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  trailing: Text(
                    localizedActivityClaimMoney(context, claim.amount),
                    textAlign: TextAlign.right,
                    style: textTheme.titleMedium?.copyWith(
                      color: _activityClaimHeadTextColor,
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
                          color: _activityClaimBodyTextColor,
                          fontSize: 15,
                          height: 1.32,
                        ),
                      ),
                      Text(
                        localizedActivityClaimActivityName(context, claim),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: _activityClaimBodyTextColor,
                          fontSize: 15,
                          height: 1.32,
                        ),
                      ),
                    ],
                  ),
                  trailing: _StatusChip(
                    label: localizedActivityClaimStatusLabel(context, claim),
                    color: color,
                    backgroundColor: _statusBackgroundColor(claim),
                  ),
                  trailingMaxWidthFactor: 0.56,
                ),
                const SizedBox(height: 3),
                Text(
                  localizedActivityClaimPayoutSummary(context, claim),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: _activityClaimBodyTextColor,
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
                      color: _activityClaimMutedTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1.32,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppTheme.claimChevron(
                      Theme.of(context).colorScheme.primary,
                    ),
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
    final iconBackground = colorScheme.primary == AppTheme.appBlue
        ? _activityClaimEmptyIconBackground
        : Color.lerp(colorScheme.primary, colorScheme.surface, 0.91) ??
              colorScheme.primaryContainer;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 54),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_giftcard_outlined,
              size: 30,
              color: AppTheme.primaryOutlineBorder(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.activityClaimsEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _activityClaimEmptyTitleColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.activityClaimsEmptySubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _activityClaimEmptyTextColor,
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
    final radius = BorderRadius.circular(999);
    final primary = Theme.of(context).colorScheme.primary;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 190, minHeight: 47),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppTheme.primaryActionStart(primary),
              AppTheme.primaryActionEnd(primary),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryActionEnd(primary).withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
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
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
  const _ActivityClaimsError({required this.message, required this.onRetry});

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

Color _statusColor(ActivityClaimItem claim) {
  if (claim.isPaid) return _activityClaimPaidColor;
  if (claim.isRejected) return _activityClaimRejectedColor;
  return _activityClaimPendingColor;
}

Color _statusBackgroundColor(ActivityClaimItem claim) {
  if (claim.isPaid) return _activityClaimPaidBackground;
  if (claim.isRejected) return _activityClaimRejectedBackground;
  return _activityClaimPendingBackground;
}

ButtonStyle _claimOutlinePillStyle(BuildContext context) {
  final primary = Theme.of(context).colorScheme.primary;
  return OutlinedButton.styleFrom(
    backgroundColor: Colors.white,
    disabledBackgroundColor: _activityClaimOutlineDisabledBackground,
    disabledForegroundColor: _activityClaimOutlineDisabledText,
    foregroundColor: AppTheme.primaryOutlineText(primary),
    minimumSize: const Size(160, 40),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    shape: const StadiumBorder(),
    textStyle: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  ).copyWith(
    splashFactory: NoSplash.splashFactory,
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled)
            ? _activityClaimOutlineDisabledBorder
            : AppTheme.primaryOutlineBorder(primary),
      ),
    ),
  );
}
