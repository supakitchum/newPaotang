import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/topup_models.dart';
import '../data/topup_repository.dart';
import 'topup_error_message.dart';
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
            maxWidth: 640,
            top: 24,
            bottom: 128,
            mobileHorizontal: 20,
            wideHorizontal: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopupHistoryHeader(
                  onTopup: () => context.go('/topup'),
                ),
                const SizedBox(height: 20),
                history.when(
                  data: (overview) => _TopupHistoryContent(
                    overview: overview,
                    page: _page,
                    onTopup: () => context.go('/topup'),
                    onPageChanged: (page) => setState(() => _page = page),
                  ),
                  loading: () => const _TopupHistoryLoading(),
                  error: (error, __) => _TopupHistoryError(
                    message: topupErrorMessage(
                      error,
                      l10n.topupHistoryLoadFailed,
                    ),
                    onRetry: () => ref.invalidate(topupHistoryProvider(_page)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopupHistoryContent extends StatelessWidget {
  const _TopupHistoryContent({
    required this.overview,
    required this.page,
    required this.onTopup,
    required this.onPageChanged,
  });

  final TopupOverview overview;
  final int page;
  final VoidCallback onTopup;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (overview.histories.isEmpty) {
      return _EmptyTopupHistory(onTopup: onTopup);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Column(
            children: [
              for (var index = 0; index < overview.histories.length; index++)
                _TopupHistoryTile(
                  item: overview.histories[index],
                  showDivider: index < overview.histories.length - 1,
                ),
            ],
          ),
        ),
        if (overview.lastPage > 1) ...[
          const SizedBox(height: 20),
          _PaginationControls(
            page: page,
            lastPage: overview.lastPage,
            onChanged: onPageChanged,
          ),
        ],
      ],
    );
  }
}

class _TopupHistoryTile extends StatelessWidget {
  const _TopupHistoryTile({required this.item, required this.showDivider});

  final TopupRequestItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.status, context);
    final l10n = context.l10n;
    final transactionAt = item.transferAt ?? item.createdAt;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.8),
                ),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth <= 360;
            final amountBlock = _HistoryAmountBlock(item: item);

            final detailBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.topupHistoryItemTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF17335F),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      l10n.topupReference(item.id),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                    ),
                    Text(
                      formatLocalizedDateTime(
                        transactionAt,
                        l10n.locale.toLanguageTag(),
                      ),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                    ),
                  ],
                ),
                if (item.bonusAmount > 0) ...[
                  const SizedBox(height: 8),
                  _HistoryBonusPill(amount: item.bonusAmount),
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
                Container(
                  width: compact ? 42 : 46,
                  height: compact ? 42 : 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    _statusIcon(item.status),
                    color: color,
                    size: compact ? 19 : 21,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: detailBlock),
                          if (!compact) ...[
                            const SizedBox(width: 12),
                            _HistoryStatusPill(
                              label: _statusLabel(item.status, l10n),
                              color: color,
                            ),
                          ],
                        ],
                      ),
                      if (compact) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _HistoryStatusPill(
                            label: _statusLabel(item.status, l10n),
                            color: color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 14),
                  amountBlock,
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

class _HistoryAmountBlock extends StatelessWidget {
  const _HistoryAmountBlock({required this.item});

  final TopupRequestItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _amountOnly(item.amount, l10n),
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF17335F),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.topupBahtSuffix,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _HistoryBonusPill extends StatelessWidget {
  const _HistoryBonusPill({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE6F8EF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 15,
                color: Color(0xFF047857),
              ),
              const SizedBox(width: 5),
              Text(
                l10n.topupHistoryBonus(formatBaht(amount)),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF047857),
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopupHistoryHeader extends StatelessWidget {
  const _TopupHistoryHeader({required this.onTopup});

  final VoidCallback onTopup;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: colorScheme.surface,
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
                          color: colorScheme.onPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.topupHistoryHeaderSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimary.withValues(alpha: 0.86),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: onTopup,
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.14),
                foregroundColor: colorScheme.onPrimary,
              ),
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
    final pages = _visiblePages(page, lastPage);
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        _PaginationButton(
          icon: Icons.chevron_left,
          enabled: page > 1,
          tooltip: context.l10n.commonBack,
          onPressed: () => onChanged(page - 1),
        ),
        for (final pageNumber in pages)
          TextButton(
            onPressed: pageNumber == page ? null : () => onChanged(pageNumber),
            style: TextButton.styleFrom(
              minimumSize: const Size.square(34),
              fixedSize: const Size.square(34),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              foregroundColor:
                  pageNumber == page ? Colors.white : const Color(0xFF17335F),
              backgroundColor: pageNumber == page
                  ? colorScheme.primary
                  : colorScheme.surface,
              disabledForegroundColor: Colors.white,
              disabledBackgroundColor: colorScheme.primary,
              side: BorderSide(
                color: pageNumber == page
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              pageNumber.toString(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        _PaginationButton(
          icon: Icons.chevron_right,
          enabled: page < lastPage,
          tooltip: context.l10n.commonNext,
          onPressed: () => onChanged(page + 1),
        ),
      ],
    );
  }

  List<int> _visiblePages(int current, int total) {
    const maxVisible = 5;
    var start = current - 2;
    if (start < 1) start = 1;
    var end = start + maxVisible - 1;
    if (end > total) {
      end = total;
      start = (end - maxVisible + 1).clamp(1, total);
    }
    return [for (var index = start; index <= end; index++) index];
  }
}

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
      iconSize: 20,
      icon: Icon(icon),
    );
  }
}

class _TopupHistoryLoading extends StatelessWidget {
  const _TopupHistoryLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          context.l10n.topupHistoryLoading,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _TopupHistoryError extends StatelessWidget {
  const _TopupHistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
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
      ),
    );
  }
}

class _EmptyTopupHistory extends StatelessWidget {
  const _EmptyTopupHistory({required this.onTopup});

  final VoidCallback onTopup;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF162E52).withValues(alpha: 0.09),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 260),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.topupHistoryEmptyTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF17335F),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.topupHistoryEmptySubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 220,
                child: FilledButton(
                  onPressed: onTopup,
                  child: Text(l10n.topupTitle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _amountOnly(num value, CustomerLocalizations l10n) {
  final amount = formatBaht(value);
  final suffix = ' ${l10n.topupBahtSuffix}';
  if (amount.endsWith(suffix)) {
    return amount.substring(0, amount.length - suffix.length);
  }
  return amount;
}
