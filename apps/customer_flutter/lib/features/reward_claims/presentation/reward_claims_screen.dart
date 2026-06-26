import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
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
          padding: const EdgeInsets.all(16),
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
                  padding: const EdgeInsets.only(bottom: 8),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.emoji_events_outlined),
        ),
        title: Text(
          l10n.rewardClaimsHeaderTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(l10n.rewardClaimsHeaderSubtitle),
        trailing: IconButton(
          tooltip: l10n.rewardClaimsTicketsTooltip,
          onPressed: onTickets,
          icon: const Icon(Icons.confirmation_number_outlined),
        ),
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      l10n.rewardClaimsPrizeTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    formatBaht(claim.prizeAmount),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final name in rewardClaimPrizeNames(l10n, claim))
                    Chip(
                      label: Text(name),
                      visualDensity: VisualDensity.compact,
                    ),
                  _StatusChip(
                    label: rewardClaimStatusLabel(l10n, claim),
                    color: color,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                rewardClaimPayoutSummary(l10n, claim),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${claim.displayReference} • '
                      '${rewardClaimSubmittedText(l10n, claim)}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
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
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
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
