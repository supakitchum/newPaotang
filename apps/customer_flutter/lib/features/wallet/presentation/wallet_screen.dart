import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../data/wallet_models.dart';
import '../data/wallet_repository.dart';
import 'wallet_localization.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(walletSummaryProvider);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.walletTitle,
      currentPath: '/my-wallet',
      sensitive: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncStateView(
            value: summary,
            data: (data) => _WalletHero(balance: data.balance),
            empty: const _WalletHero(balance: 0),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.walletRecentLedger,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          AsyncStateView(
            value: summary,
            data: (data) {
              if (data.ledger.isEmpty) return const _WalletEmptyLedger();
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
    );
  }
}

class _WalletHero extends StatelessWidget {
  const _WalletHero({required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              context.l10n.commonWalletBalance,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            Text(
              formatBaht(balance),
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _WalletActionButton(
                  icon: Icons.add,
                  label: context.l10n.homeActionTopup,
                  onPressed: () => context.go('/topup'),
                ),
                _WalletActionButton(
                  icon: Icons.payments_outlined,
                  label: context.l10n.homeActionClaim,
                  onPressed: () => context.go('/reward-claims'),
                ),
                _WalletActionButton(
                  icon: Icons.history,
                  label: context.l10n.homeActionHistory,
                  onPressed: () => context.go('/topup/history'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
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
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            entry.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),
        ),
        title: Text(walletLedgerTitle(context.l10n, entry)),
        subtitle: Text(
          '${walletLedgerSubtitle(context.l10n, entry)}\n'
          '${walletLedgerDate(context.l10n, entry)}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatSignedBaht(entry.amount),
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
            Text(
              context.l10n.walletBalanceAfter(formatBaht(entry.balanceAfter)),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
