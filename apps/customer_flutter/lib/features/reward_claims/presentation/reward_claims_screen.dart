import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/reward_claim_models.dart';
import '../data/reward_claim_repository.dart';
import 'claim_realtime_monitor.dart';
import 'reward_claim_error_message.dart';
import 'reward_claim_localization.dart';

const _rewardClaimHeadTextColor = Color(0xFF202938);
const _rewardClaimBodyTextColor = Color(0xFF4B5563);
const _rewardClaimMutedTextColor = Color(0xFF94A3B8);
const _rewardClaimDividerColor = Color(0xFFEEF2F7);
const _rewardClaimChevronColor = Color(0xFF3B9CFF);
const _rewardClaimEmptyIconColor = Color(0xFF0B69DC);
const _rewardClaimEmptyIconBackground = Color(0xFFEEF7FF);
const _rewardClaimEmptyTitleColor = Color(0xFF111827);
const _rewardClaimEmptyTextColor = Color(0xFF64748B);
const _rewardClaimPaidColor = Color(0xFF28A81E);
const _rewardClaimPaidBackground = Color(0xFFE5F8DF);
const _rewardClaimPendingColor = Color(0xFFE29300);
const _rewardClaimPendingBackground = Color(0xFFFFF3D0);
const _rewardClaimRejectedColor = Color(0xFFED2C25);
const _rewardClaimRejectedBackground = Color(0xFFFFE1DF);
const _rewardClaimPrimaryStart = Color(0xFF149AF9);
const _rewardClaimPrimaryEnd = Color(0xFF0064D5);
const _rewardClaimPrimaryShadow = Color(0x380066D5);
const _rewardClaimOutlineBorder = Color(0xFF0B69DC);
const _rewardClaimOutlineText = Color(0xFF075EC9);
const _rewardClaimOutlineDisabledBorder = Color(0xFFCBD4DF);
const _rewardClaimOutlineDisabledText = Color(0xFF8A8F98);
const _rewardClaimOutlineDisabledBackground = Color(0xFFF2F4F7);

class RewardClaimsScreen extends ConsumerStatefulWidget {
  const RewardClaimsScreen({super.key});

  @override
  ConsumerState<RewardClaimsScreen> createState() => _RewardClaimsScreenState();
}

class _RewardClaimsScreenState extends ConsumerState<RewardClaimsScreen> {
  final _claims = <RewardClaimItem>[];
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
      rewardClaimRealtimeTickProvider,
      (_, __) => _scheduleRealtimeRefresh(),
    );

    return AppShell(
      title: l10n.rewardClaimsHeaderTitle,
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
        child: _RewardClaimsPageBody(
          child: _RewardClaimsContent(
            claims: List<RewardClaimItem>.unmodifiable(_claims),
            hasMore: _hasMore,
            loadingInitial: _loadingInitial,
            loadingMore: _loadingMore,
            error: _error,
            refreshError: _refreshError,
            loadMoreError: _loadMoreError,
            onRefreshRetry: () => _loadInitial(
              showLoading: false,
              preserveDataOnError: true,
            ),
            onLoadMore: _loadMore,
            onTickets: () => context.go('/tickets/history'),
            onClaim: (claim) => context.go('/reward-claims/${claim.id}'),
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
      final page = await ref.read(rewardClaimRepositoryProvider).list();
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
      final message = rewardClaimErrorMessage(
        error,
        context.l10n.rewardClaimsLoadFailed,
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
          await ref.read(rewardClaimRepositoryProvider).list(cursor: cursor);
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
          () => _loadMoreError = rewardClaimErrorMessage(
            error,
            context.l10n.rewardClaimsLoadMoreFailed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }
}

class _RewardClaimsPageBody extends StatelessWidget {
  const _RewardClaimsPageBody({required this.child});

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

class _RewardClaimsContent extends StatelessWidget {
  const _RewardClaimsContent({
    required this.claims,
    required this.hasMore,
    required this.loadingInitial,
    required this.loadingMore,
    required this.error,
    required this.refreshError,
    required this.loadMoreError,
    required this.onRefreshRetry,
    required this.onLoadMore,
    required this.onTickets,
    required this.onClaim,
  });

  final List<RewardClaimItem> claims;
  final bool hasMore;
  final bool loadingInitial;
  final bool loadingMore;
  final String error;
  final String refreshError;
  final String loadMoreError;
  final VoidCallback onRefreshRetry;
  final VoidCallback onLoadMore;
  final VoidCallback onTickets;
  final ValueChanged<RewardClaimItem> onClaim;

  @override
  Widget build(BuildContext context) {
    if (loadingInitial) {
      return const _RewardClaimsLoading();
    }

    if (error.isNotEmpty) {
      return _RewardClaimsError(message: error, onRetry: onRefreshRetry);
    }

    if (claims.isEmpty) {
      return _RewardClaimsEmpty(onTickets: onTickets);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          key: const ValueKey('reward-claims-list'),
          children: [
            if (refreshError.isNotEmpty)
              _RewardClaimsInlineError(
                message: refreshError,
                onRetry: onRefreshRetry,
              ),
            for (var index = 0; index < claims.length; index++)
              _RewardClaimTile(
                claim: claims[index],
                showDivider: index < claims.length - 1,
                onTap: () => onClaim(claims[index]),
              ),
          ],
        ),
        if (loadMoreError.isNotEmpty)
          _RewardClaimsInlineError(
            message: loadMoreError,
            onRetry: onLoadMore,
          ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: OutlinedButton(
                style: _claimOutlinePillStyle(context),
                onPressed: loadingMore ? null : onLoadMore,
                child: Text(
                  loadingMore
                      ? context.l10n.rewardClaimsLoadingMore
                      : context.l10n.rewardClaimsLoadMore,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RewardClaimTile extends StatelessWidget {
  const _RewardClaimTile({
    required this.claim,
    required this.showDivider,
    required this.onTap,
  });

  final RewardClaimItem claim;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(claim);
    final l10n = context.l10n;
    final prizeNames = rewardClaimPrizeNames(l10n, claim);
    final submittedAt = rewardClaimSubmittedText(l10n, claim);

    return Semantics(
      button: true,
      label: [
        l10n.rewardClaimsPrizeTitle,
        claim.ticket?.number ?? '-',
        claim.displayReference,
      ].join(' '),
      child: Material(
        color: Colors.white,
        child: InkWell(
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: showDivider
                  ? Border(
                      bottom: BorderSide(color: _rewardClaimDividerColor),
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RewardClaimRowLine(
                    leading: Text(
                      l10n.rewardClaimsPrizeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _rewardClaimHeadTextColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                    ),
                    trailing: Text(
                      formatRewardClaimBaht(l10n, claim.prizeAmount),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _rewardClaimHeadTextColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  _RewardClaimRowLine(
                    leading: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final name in prizeNames)
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: _rewardClaimBodyTextColor,
                                  fontSize: 15,
                                  height: 1.32,
                                ),
                          ),
                      ],
                    ),
                    trailing: _StatusChip(
                      label: rewardClaimStatusLabel(l10n, claim),
                      color: color,
                      backgroundColor: _statusBackgroundColor(claim),
                    ),
                    trailingMaxWidthFactor: 0.56,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    rewardClaimPayoutSummary(l10n, claim),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _rewardClaimBodyTextColor,
                          fontSize: 15,
                          height: 1.32,
                        ),
                  ),
                  const SizedBox(height: 3),
                  _RewardClaimRowLine(
                    leading: Text(
                      submittedAt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _rewardClaimMutedTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            height: 1.32,
                          ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: _rewardClaimChevronColor,
                      size: 23,
                    ),
                    trailingMaxWidthFactor: 0.2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardClaimRowLine extends StatelessWidget {
  const _RewardClaimRowLine({
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

class _RewardClaimsLoading extends StatelessWidget {
  const _RewardClaimsLoading();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _RewardClaimsStatePanel(
      child: Text(
        context.l10n.rewardClaimsLoading,
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

class _RewardClaimsError extends StatelessWidget {
  const _RewardClaimsError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _RewardClaimsStatePanel(
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

class _RewardClaimsInlineError extends StatelessWidget {
  const _RewardClaimsInlineError({
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

class _RewardClaimsEmpty extends StatelessWidget {
  const _RewardClaimsEmpty({required this.onTickets});

  final VoidCallback onTickets;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 54),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _rewardClaimEmptyIconBackground,
            ),
            child: Icon(
              Icons.emoji_events_outlined,
              color: _rewardClaimEmptyIconColor,
              size: 30,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.rewardClaimsEmptyTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _rewardClaimEmptyTitleColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.rewardClaimsEmptySubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _rewardClaimEmptyTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          _RewardClaimsPrimaryPill(
            label: l10n.rewardClaimsViewWinningTickets,
            onPressed: onTickets,
          ),
        ],
      ),
    );
  }
}

class _RewardClaimsPrimaryPill extends StatelessWidget {
  const _RewardClaimsPrimaryPill({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 190, minHeight: 47),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [_rewardClaimPrimaryStart, _rewardClaimPrimaryEnd],
          ),
          boxShadow: [
            BoxShadow(
              color: _rewardClaimPrimaryShadow,
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

class _RewardClaimsStatePanel extends StatelessWidget {
  const _RewardClaimsStatePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 52),
      child: Center(child: child),
    );
  }
}

Color _statusColor(RewardClaimItem claim) {
  if (claim.isPaid) return _rewardClaimPaidColor;
  if (claim.isRejected) return _rewardClaimRejectedColor;
  return _rewardClaimPendingColor;
}

Color _statusBackgroundColor(RewardClaimItem claim) {
  if (claim.isPaid) return _rewardClaimPaidBackground;
  if (claim.isRejected) return _rewardClaimRejectedBackground;
  return _rewardClaimPendingBackground;
}

ButtonStyle _claimOutlinePillStyle(BuildContext context) {
  return OutlinedButton.styleFrom(
    backgroundColor: Colors.white,
    disabledBackgroundColor: _rewardClaimOutlineDisabledBackground,
    disabledForegroundColor: _rewardClaimOutlineDisabledText,
    foregroundColor: _rewardClaimOutlineText,
    minimumSize: const Size(160, 40),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    shape: const StadiumBorder(),
    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
  ).copyWith(
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled)
            ? _rewardClaimOutlineDisabledBorder
            : _rewardClaimOutlineBorder,
      ),
    ),
  );
}
