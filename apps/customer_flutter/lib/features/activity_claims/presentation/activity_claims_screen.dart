import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../data/activity_claim_models.dart';
import '../data/activity_claim_repository.dart';
import '../../reward_claims/presentation/claim_realtime_monitor.dart';
import 'activity_claim_localization.dart';

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
      activityClaimRealtimeTickProvider,
      (_, __) => _scheduleRealtimeRefresh(),
    );
    return AppShell(
      title: l10n.activityClaimsTitle,
      currentPath: '/profile',
      sensitive: true,
      child: RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _ActivityClaimsHeader(
              onActivities: () => context.go('/activities'),
            ),
            const SizedBox(height: 12),
            if (_loadingInitial)
              const _ActivityClaimsLoading()
            else if (_error.isNotEmpty)
              _ActivityClaimsError(message: _error, onRetry: _loadInitial)
            else if (_claims.isEmpty)
              _ActivityClaimsEmpty(
                onActivities: () => context.go('/activities'),
              )
            else ...[
              for (final claim in _claims)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ActivityClaimTile(
                    claim: claim,
                    onTap: () => context.go('/activity-claims/${claim.id}'),
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
                          ? l10n.commonLoadingMore
                          : l10n.commonLoadMore,
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
      final page = await ref.read(activityClaimRepositoryProvider).list();
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
      setState(() => _error = context.l10n.activityClaimsLoadFailed);
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
          await ref.read(activityClaimRepositoryProvider).list(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _claims.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.activityClaimsLoadMoreFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }
}

class _ActivityClaimsHeader extends StatelessWidget {
  const _ActivityClaimsHeader({required this.onActivities});

  final VoidCallback onActivities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.redeem_outlined),
        ),
        title: Text(
          l10n.activityClaimsHeaderTitle,
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(l10n.activityClaimsHeaderSubtitle),
        trailing: IconButton(
          tooltip: l10n.activityClaimsActivitiesTooltip,
          onPressed: onActivities,
          icon: const Icon(Icons.local_activity_outlined),
        ),
      ),
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
                      l10n.activityClaimsPrizeTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    formatBaht(claim.amount),
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
                  Chip(
                    label:
                        Text(localizedActivityClaimRewardLabel(context, claim)),
                    visualDensity: VisualDensity.compact,
                  ),
                  _StatusChip(
                    label: localizedActivityClaimStatusLabel(context, claim),
                    color: color,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                localizedActivityClaimActivityName(context, claim),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                localizedActivityClaimPayoutSummary(context, claim),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      localizedActivityClaimSubmittedAt(context, claim),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
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
    return Chip(
      backgroundColor: color.withValues(alpha: 0.12),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ActivityClaimsEmpty extends StatelessWidget {
  const _ActivityClaimsEmpty({required this.onActivities});

  final VoidCallback onActivities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.redeem_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.activityClaimsEmptyTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.activityClaimsEmptySubtitle,
              style: TextStyle(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onActivities,
              icon: const Icon(Icons.local_activity_outlined),
              label: Text(l10n.activityClaimsViewActivities),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityClaimsLoading extends StatelessWidget {
  const _ActivityClaimsLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
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
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(ActivityClaimItem claim) {
  if (claim.isPaid) return Colors.green.shade700;
  if (claim.isRejected) return Colors.red.shade700;
  return Colors.orange.shade800;
}
