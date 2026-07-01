import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../data/reward_claim_models.dart';
import '../data/reward_claim_repository.dart';
import 'claim_realtime_monitor.dart';
import 'reward_claim_error_message.dart';
import 'reward_claim_localization.dart';

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
  String _error = '';

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
      currentPath: '/my-wallet',
      backPath: '/profile',
      sensitive: true,
      child: RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 128),
                  child: _RewardClaimsContent(
                    claims: List<RewardClaimItem>.unmodifiable(_claims),
                    hasMore: _hasMore,
                    loadingInitial: _loadingInitial,
                    loadingMore: _loadingMore,
                    error: _error,
                    onRetry: _loadInitial,
                    onLoadMore: _loadMore,
                    onTickets: () => context.go('/tickets/history'),
                    onClaim: (claim) =>
                        context.go('/reward-claims/${claim.id}'),
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
    if (!mounted || _loadingInitial) return;
    Future.microtask(() {
      if (mounted && !_loadingInitial) {
        _loadInitial();
      }
    });
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _error = '';
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
      setState(
        () => _error = rewardClaimErrorMessage(
          error,
          context.l10n.rewardClaimsLoadFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || cursor.isEmpty || _loadingMore) return;

    setState(() => _loadingMore = true);
    try {
      final page =
          await ref.read(rewardClaimRepositoryProvider).list(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _claims.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rewardClaimErrorMessage(
                error,
                context.l10n.rewardClaimsLoadMoreFailed,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }
}

class _RewardClaimsContent extends StatelessWidget {
  const _RewardClaimsContent({
    required this.claims,
    required this.hasMore,
    required this.loadingInitial,
    required this.loadingMore,
    required this.error,
    required this.onRetry,
    required this.onLoadMore,
    required this.onTickets,
    required this.onClaim,
  });

  final List<RewardClaimItem> claims;
  final bool hasMore;
  final bool loadingInitial;
  final bool loadingMore;
  final String error;
  final Future<void> Function() onRetry;
  final VoidCallback onLoadMore;
  final VoidCallback onTickets;
  final ValueChanged<RewardClaimItem> onClaim;

  @override
  Widget build(BuildContext context) {
    if (loadingInitial) {
      return const _RewardClaimsLoading();
    }

    if (error.isNotEmpty) {
      return _RewardClaimsError(message: error, onRetry: onRetry);
    }

    if (claims.isEmpty) {
      return _RewardClaimsEmpty(onTickets: onTickets);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Column(
            children: [
              for (var index = 0; index < claims.length; index++)
                _RewardClaimTile(
                  claim: claims[index],
                  showDivider: index < claims.length - 1,
                  onTap: () => onClaim(claims[index]),
                ),
            ],
          ),
        ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: OutlinedButton(
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
    final colorScheme = Theme.of(context).colorScheme;
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
        color: colorScheme.surface,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: showDivider
                  ? Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
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
                            color: const Color(0xFF202938),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                    ),
                    trailing: Text(
                      formatBaht(claim.prizeAmount),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF202938),
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
                                  color: const Color(0xFF4B5563),
                                  fontSize: 15,
                                  height: 1.32,
                                ),
                          ),
                      ],
                    ),
                    trailing: _StatusChip(
                      label: rewardClaimStatusLabel(l10n, claim),
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    rewardClaimPayoutSummary(l10n, claim),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF4B5563),
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
                            color: const Color(0xFF94A3B8),
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
  const _RewardClaimRowLine({required this.leading, required this.trailing});

  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 330;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerLeft, child: trailing),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: leading),
            const SizedBox(width: 10),
            Flexible(
              flex: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.46,
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
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: color.withValues(alpha: 0.13),
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
    return _RewardClaimsStatePanel(
      child: Text(
        context.l10n.rewardClaimsLoading,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _RewardClaimsError extends StatelessWidget {
  const _RewardClaimsError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return _RewardClaimsStatePanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(context.l10n.commonRetry),
          ),
        ],
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

    return _RewardClaimsStatePanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Icon(
              Icons.emoji_events_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.rewardClaimsEmptyTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.rewardClaimsEmptySubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onTickets,
            child: Text(l10n.rewardClaimsViewWinningTickets),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(14, 54, 14, 24),
      child: Center(child: child),
    );
  }
}

Color _statusColor(RewardClaimItem claim) {
  if (claim.isPaid) return const Color(0xFF28A81E);
  if (claim.isRejected) return const Color(0xFFED2C25);
  return const Color(0xFFE29300);
}
