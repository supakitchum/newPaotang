import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/topup_models.dart';
import '../data/topup_repository.dart';
import 'topup_realtime_monitor.dart';

class TopupHistoryScreen extends ConsumerStatefulWidget {
  const TopupHistoryScreen({super.key});

  @override
  ConsumerState<TopupHistoryScreen> createState() => _TopupHistoryScreenState();
}

class _TopupHistoryScreenState extends ConsumerState<TopupHistoryScreen> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(topupRealtimeTickProvider, (previous, next) {
      if (previous == null || previous == next) return;
      ref.invalidate(topupHistoryProvider(_page));
    });

    final history = ref.watch(topupHistoryProvider(_page));
    final l10n = context.l10n;

    return AppShell(
      title: l10n.topupHistoryTitle,
      currentPath: '/my-wallet',
      sensitive: true,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          CustomerPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopupHistoryHeader(
                  onTopup: () => context.go('/topup'),
                ),
                const SizedBox(height: 12),
                AsyncStateView(
                  value: history,
                  data: (overview) {
                    if (overview.histories.isEmpty) {
                      return const _EmptyTopupHistory();
                    }
                    return Column(
                      children: [
                        for (final item in overview.histories)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TopupHistoryTile(item: item),
                          ),
                        if (overview.lastPage > 1)
                          _PaginationControls(
                            page: _page,
                            lastPage: overview.lastPage,
                            onChanged: (page) => setState(() => _page = page),
                          ),
                      ],
                    );
                  },
                  empty: const _EmptyTopupHistory(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopupHistoryTile extends StatelessWidget {
  const _TopupHistoryTile({required this.item});

  final TopupRequestItem item;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.status, context);
    final l10n = context.l10n;
    final transactionAt = item.transferAt ?? item.createdAt;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 390;
            final amountBlock = DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatBaht(item.amount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    _HistoryStatusPill(
                      label: _statusLabel(item.status, l10n),
                      color: color,
                    ),
                  ],
                ),
              ),
            );

            final detailBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.topupHistoryItemTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.topupHistoryReference(
                    item.id,
                    _channelLabel(item.channel, l10n),
                    formatLocalizedDateTime(
                      transactionAt,
                      l10n.locale.toLanguageTag(),
                    ),
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
                if (item.bonusAmount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          l10n.topupHistoryBonus(formatBaht(item.bonusAmount)),
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (compact) ...[
                  const SizedBox(height: 10),
                  amountBlock,
                ],
              ],
            );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(_statusIcon(item.status), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(child: detailBlock),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Flexible(child: amountBlock),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Color _statusColor(TopupStatus status, BuildContext context) {
    return switch (status) {
      TopupStatus.approved => Colors.green.shade700,
      TopupStatus.rejected ||
      TopupStatus.cancelled ||
      TopupStatus.expired =>
        Colors.red.shade700,
      TopupStatus.pendingPayment ||
      TopupStatus.pendingReview =>
        Colors.orange.shade800,
      TopupStatus.unknown => Theme.of(context).colorScheme.primary,
    };
  }

  IconData _statusIcon(TopupStatus status) {
    return switch (status) {
      TopupStatus.approved => Icons.check,
      TopupStatus.rejected ||
      TopupStatus.cancelled ||
      TopupStatus.expired =>
        Icons.close,
      TopupStatus.pendingPayment ||
      TopupStatus.pendingReview =>
        Icons.hourglass_bottom,
      TopupStatus.unknown => Icons.account_balance_wallet_outlined,
    };
  }

  String _channelLabel(TopupChannel channel, CustomerLocalizations l10n) {
    return switch (channel) {
      TopupChannel.qr => l10n.topupChannelQrLabel,
      TopupChannel.creditCard => l10n.topupChannelCreditLabel,
      TopupChannel.bankTransfer => l10n.topupChannelBankLabel,
    };
  }

  String _statusLabel(TopupStatus status, CustomerLocalizations l10n) {
    return switch (status) {
      TopupStatus.pendingPayment => l10n.topupStatusPendingPayment,
      TopupStatus.pendingReview => l10n.topupStatusPendingReview,
      TopupStatus.approved => l10n.topupStatusApproved,
      TopupStatus.rejected => l10n.topupStatusRejected,
      TopupStatus.cancelled => l10n.topupStatusCancelled,
      TopupStatus.expired => l10n.topupStatusExpired,
      TopupStatus.unknown => l10n.topupStatusUnknown,
    };
  }
}

class _TopupHistoryHeader extends StatelessWidget {
  const _TopupHistoryHeader({required this.onTopup});

  final VoidCallback onTopup;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.history, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.topupHistoryHeaderTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.topupHistoryHeaderSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: onTopup,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryStatusPill extends StatelessWidget {
  const _HistoryStatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.page,
    required this.lastPage,
    required this.onChanged,
  });

  final int page;
  final int lastPage;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: page <= 1 ? null : () => onChanged(page - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('$page / $lastPage'),
            IconButton(
              onPressed: page >= lastPage ? null : () => onChanged(page + 1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTopupHistory extends StatelessWidget {
  const _EmptyTopupHistory();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.receipt_long_outlined, size: 42),
            const SizedBox(height: 12),
            Text(l10n.topupHistoryEmptyTitle),
            const SizedBox(height: 4),
            Text(l10n.topupHistoryEmptySubtitle),
          ],
        ),
      ),
    );
  }
}
