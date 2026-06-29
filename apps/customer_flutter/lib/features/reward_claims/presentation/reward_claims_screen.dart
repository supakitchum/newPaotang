import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/reward_claim_models.dart';
import '../data/reward_claim_repository.dart';
import 'claim_realtime_monitor.dart';
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
      title: l10n.rewardClaimsTitle,
      currentPath: '/my-wallet',
      sensitive: true,
      child: RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            CustomerPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RewardClaimsHeader(
                    onTickets: () => context.go('/tickets/history'),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingInitial)
                    const _RewardClaimsLoading()
                  else if (_error.isNotEmpty)
                    _RewardClaimsError(message: _error, onRetry: _loadInitial)
                  else if (_claims.isEmpty)
                    _RewardClaimsEmpty(
                      onTickets: () => context.go('/tickets/history'),
                    )
                  else ...[
                    for (final claim in _claims)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RewardClaimTile(
                          claim: claim,
                          onTap: () => context.go('/reward-claims/${claim.id}'),
                        ),
                      ),
                    if (_hasMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: OutlinedButton.icon(
                          onPressed: _loadingMore ? null : _loadMore,
                          icon: _loadingMore
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.expand_more),
                          label: Text(
                            _loadingMore
                                ? l10n.rewardClaimsLoadingMore
                                : l10n.rewardClaimsLoadMore,
                          ),
                        ),
                      ),
                  ],
                ],
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = context.l10n.rewardClaimsLoadFailed);
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.rewardClaimsLoadMoreFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }
}

class _RewardClaimsHeader extends StatelessWidget {
  const _RewardClaimsHeader({required this.onTickets});

  final VoidCallback onTickets;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            Color.lerp(colorScheme.primary, colorScheme.secondary, 0.58) ??
                colorScheme.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -42,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  child: const Icon(
                    Icons.emoji_events_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.rewardClaimsHeaderTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.rewardClaimsHeaderSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.84),
                              fontWeight: FontWeight.w700,
                              height: 1.32,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    foregroundColor: Colors.white,
                  ),
                  tooltip: l10n.rewardClaimsTicketsTooltip,
                  onPressed: onTickets,
                  icon: const Icon(Icons.confirmation_number_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardClaimTile extends StatelessWidget {
  const _RewardClaimTile({required this.claim, required this.onTap});

  final RewardClaimItem claim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(claim);
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 370;
              final amountBlock = Column(
                crossAxisAlignment:
                    compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  Text(
                    formatBaht(claim.prizeAmount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  _StatusChip(
                    label: rewardClaimStatusLabel(l10n, claim),
                    color: color,
                  ),
                ],
              );

              final detailBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.rewardClaimsPrizeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final name in rewardClaimPrizeNames(l10n, claim))
                        _RewardTag(label: name),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    rewardClaimPayoutSummary(l10n, claim),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${claim.displayReference} • '
                    '${rewardClaimSubmittedText(l10n, claim)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (compact) ...[
                    const SizedBox(height: 12),
                    amountBlock,
                  ],
                ],
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(Icons.emoji_events_outlined, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: detailBlock),
                  if (!compact) ...[
                    const SizedBox(width: 12),
                    amountBlock,
                  ],
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RewardTag extends StatelessWidget {
  const _RewardTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _RewardClaimsLoading extends StatelessWidget {
  const _RewardClaimsLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Center(child: CircularProgressIndicator()),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.emoji_events_outlined, size: 42),
            const SizedBox(height: 12),
            Text(
              l10n.rewardClaimsEmptyTitle,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.rewardClaimsEmptySubtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onTickets,
              child: Text(l10n.rewardClaimsViewWinningTickets),
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(RewardClaimItem claim) {
  if (claim.isPaid) return Colors.green.shade700;
  if (claim.isRejected) return Colors.red.shade700;
  return Colors.orange.shade800;
}
