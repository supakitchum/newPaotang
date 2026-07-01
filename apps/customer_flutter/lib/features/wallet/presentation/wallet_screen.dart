import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/customer_wallet_card.dart';
import '../data/wallet_models.dart';
import '../data/wallet_repository.dart';
import 'wallet_localization.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(walletSummaryProvider);
    final l10n = context.l10n;
    Future<void> refreshWallet() async {
      ref.invalidate(walletSummaryProvider);
      await ref.read(walletSummaryProvider.future);
    }

    return AppShell(
      title: l10n.walletTitle,
      currentPath: '/my-wallet',
      backPath: '/profile',
      sensitive: true,
      child: RefreshIndicator(
        onRefresh: refreshWallet,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            CustomerPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AsyncStateView(
                    value: summary,
                    data: (data) => CustomerWalletBalanceCard(
                      balance: data.balance,
                      title: l10n.commonWalletBalance,
                      onOpenWallet: () => context.go('/my-wallet'),
                      actions: _walletCardActions(context),
                    ),
                    empty: CustomerWalletBalanceCard(
                      balance: 0,
                      title: l10n.commonWalletBalance,
                      onOpenWallet: () => context.go('/my-wallet'),
                      actions: _walletCardActions(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _WalletLedgerHeader(
                    loading: summary.isLoading,
                    onRefresh: refreshWallet,
                  ),
                  const SizedBox(height: 10),
                  AsyncStateView(
                    value: summary,
                    data: (data) {
                      if (data.ledgerLoadFailed) {
                        return _WalletLedgerLoadFailed(
                          message: data.ledgerErrorMessage,
                          onRetry: refreshWallet,
                        );
                      }
                      if (data.ledger.isEmpty) {
                        return const _WalletEmptyLedger();
                      }
                      return _WalletLedgerList(entries: data.ledger);
                    },
                    empty: const _WalletEmptyLedger(),
                    loadingText: l10n.walletLedgerLoading,
                    errorText: l10n.walletLedgerLoadFailed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletLedgerLoadFailed extends StatelessWidget {
  const _WalletLedgerLoadFailed({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final body = message.trim().isEmpty
        ? l10n.walletLedgerLoadFailedMessage
        : message.trim();
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
        constraints: const BoxConstraints(minHeight: 220),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 32,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.walletLedgerLoadFailed,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => onRetry(),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletLedgerHeader extends StatelessWidget {
  const _WalletLedgerHeader({
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.walletRecentLedger,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF17335F),
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.walletRecentLedgerSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          tooltip: l10n.walletRefreshTooltip,
          onPressed: loading ? null : () => onRefresh(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _WalletEmptyLedger extends StatelessWidget {
  const _WalletEmptyLedger();

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.walletEmptyLedgerTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF17335F),
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.walletEmptyLedgerSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletLedgerList extends StatelessWidget {
  const _WalletLedgerList({required this.entries});

  final List<WalletLedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            _WalletLedgerTile(entry: entries[index]),
            if (index < entries.length - 1)
              Divider(
                height: 1,
                indent: 64,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.72),
              ),
          ],
        ],
      ),
    );
  }
}

List<CustomerWalletCardAction> _walletCardActions(BuildContext context) {
  final l10n = context.l10n;
  return [
    CustomerWalletCardAction(
      icon: Icons.add,
      label: l10n.homeActionTopup,
      onTap: () => context.go('/topup'),
    ),
    CustomerWalletCardAction(
      icon: Icons.confirmation_number_outlined,
      label: l10n.homeActionTickets,
      onTap: () => context.go('/tickets'),
    ),
    CustomerWalletCardAction(
      icon: Icons.payments_outlined,
      label: l10n.homeActionClaim,
      onTap: () => context.go('/reward-claims'),
    ),
    CustomerWalletCardAction(
      icon: Icons.history,
      label: l10n.homeActionHistory,
      onTap: () => context.go('/topup/history'),
    ),
  ];
}

class _WalletLedgerTile extends StatelessWidget {
  const _WalletLedgerTile({required this.entry});

  final WalletLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = entry.isCredit
        ? Colors.green.shade700
        : entry.isDebit
            ? Colors.red.shade700
            : Theme.of(context).colorScheme.onSurfaceVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final amount = _WalletLedgerAmount(entry: entry, color: color);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(_entryIcon(entry), color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      walletLedgerTitle(context.l10n, entry),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: const Color(0xFF17335F),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      walletLedgerSubtitle(context.l10n, entry),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      walletLedgerDate(context.l10n, entry),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (compact) ...[
                      const SizedBox(height: 6),
                      amount,
                    ],
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 132),
                  child: amount,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  IconData _entryIcon(WalletLedgerEntry entry) {
    if (entry.isCredit) return Icons.arrow_downward;
    if (entry.isDebit) return Icons.arrow_upward;
    return Icons.account_balance_wallet_outlined;
  }
}

class _WalletLedgerAmount extends StatelessWidget {
  const _WalletLedgerAmount({
    required this.entry,
    required this.color,
  });

  final WalletLedgerEntry entry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            formatSignedBaht(entry.amount),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.walletBalanceAfter(
            formatBaht(entry.balanceAfter),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
