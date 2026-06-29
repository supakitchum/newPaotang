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
                      if (data.ledger.isEmpty) {
                        return const _WalletEmptyLedger();
                      }
                      return Column(
                        children: [
                          for (final entry in data.ledger)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _WalletLedgerTile(entry: entry),
                            ),
                        ],
                      );
                    },
                    empty: const _WalletEmptyLedger(),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            l10n.walletRecentLedger,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
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
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
        title: Text(context.l10n.walletEmptyLedgerTitle),
        subtitle: Text(context.l10n.walletEmptyLedgerSubtitle),
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

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                entry.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    walletLedgerTitle(context.l10n, entry),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    walletLedgerSubtitle(context.l10n, entry),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    walletLedgerDate(context.l10n, entry),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
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
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
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
