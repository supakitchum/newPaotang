import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/customer_wallet_card.dart';
import '../../profile/data/profile_settings_repository.dart';
import '../data/wallet_models.dart';
import '../data/wallet_repository.dart';
import 'wallet_localization.dart';

Color _walletPrimaryTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.primary, colorScheme.surface, 0.88) ??
    colorScheme.primary.withValues(alpha: 0.12);

Color _walletCreditColor(ColorScheme colorScheme) => const Color(0xFF078254);

Color _walletCreditBackground(ColorScheme colorScheme) =>
    const Color(0xFFE7F8EF);

Color _walletDebitColor(ColorScheme colorScheme) => const Color(0xFFD33B38);

Color _walletDebitBackground(ColorScheme colorScheme) =>
    const Color(0xFFFFECEC);

Color _walletNeutralColor(ColorScheme colorScheme) => const Color(0xFF64748B);

Color _walletNeutralBackground(ColorScheme colorScheme) =>
    const Color(0xFFEEF2F7);

Color _walletPanelBorder(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.outlineVariant, colorScheme.surface, 0.18) ??
    colorScheme.outlineVariant;

Color _walletPanelShadow(ColorScheme colorScheme) =>
    colorScheme.primary.withValues(alpha: 0.08);

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _transactionsKey = GlobalKey();
  bool _transactionsScrollScheduled = false;
  String _lastHandledFragment = '';

  void _scheduleTransactionsScroll() {
    if (_transactionsScrollScheduled) return;
    _transactionsScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transactionsScrollScheduled = false;
      if (!mounted) return;
      final targetContext = _transactionsKey.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.02,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _syncTransactionsFragment(BuildContext context) {
    final fragment = _currentRouteUri(context)?.fragment ?? '';
    if (fragment == 'transactions') {
      if (_lastHandledFragment != fragment) {
        _lastHandledFragment = fragment;
        _scheduleTransactionsScroll();
      }
      return;
    }
    _lastHandledFragment = '';
  }

  void _openTransactions() {
    final uri = _currentRouteUri(context);
    if (uri?.fragment != 'transactions') {
      try {
        context.go('/my-wallet#transactions');
      } on GoError {
        // Widget harnesses can render WalletScreen without a GoRouter.
      }
    }
    _scheduleTransactionsScroll();
  }

  Uri? _currentRouteUri(BuildContext context) {
    try {
      return GoRouterState.of(context).uri;
    } on GoError {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncTransactionsFragment(context);
    final summary = ref.watch(walletSummaryProvider);
    final l10n = context.l10n;
    Future<void> refreshWallet() async {
      ref.invalidate(walletSummaryProvider);
      try {
        await ref.read(walletSummaryProvider.future);
      } catch (_) {
        // The provider state renders the error panel; keep refresh gestures
        // from surfacing an unhandled async exception.
      }
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
            _WalletHeroSection(
              child: _WalletHeroCard(
                summary: summary,
                onOpenWallet: () => context.go('/my-wallet'),
                actions: _walletCardActions(
                  context,
                  onShowTransactions: _openTransactions,
                ),
              ),
            ),
            _WalletLedgerSheet(
              key: _transactionsKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WalletLedgerHeader(
                    loading: summary.isLoading,
                    onRefresh: refreshWallet,
                  ),
                  const SizedBox(height: 12),
                  summary.when(
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
                    loading: () => const _WalletLedgerLoading(),
                    error: (_, __) => _WalletLedgerLoadFailed(
                      message: l10n.walletLedgerLoadFailedMessage,
                      onRetry: refreshWallet,
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

class _WalletHeroSection extends StatelessWidget {
  const _WalletHeroSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            AppTheme.heroGradientEnd(colorScheme.primary),
          ],
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 304),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 720 ? 28.0 : 18.0;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 34),
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

String _walletCustomerLabel(
  CustomerLocalizations l10n,
  String customerNo,
) {
  final normalized = customerNo.trim();
  return l10n.profileMemberCode(normalized.isEmpty ? '-' : normalized);
}

class _WalletHeroCard extends ConsumerWidget {
  const _WalletHeroCard({
    required this.summary,
    required this.onOpenWallet,
    required this.actions,
  });

  final AsyncValue<WalletSummary> summary;
  final VoidCallback onOpenWallet;
  final List<CustomerWalletCardAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return summary.when(
      data: (data) {
        final profileCustomerNo = data.customerNo.trim().isEmpty
            ? ref.watch(customerProfileSettingsProvider).maybeWhen(
                  data: (profile) => profile.customerNo,
                  orElse: () => '',
                )
            : '';
        return CustomerWalletBalanceCard(
          balance: data.balance,
          title: l10n.commonWalletBalance,
          customerLabel: _walletCustomerLabel(
            l10n,
            data.customerNo.trim().isEmpty
                ? profileCustomerNo
                : data.customerNo,
          ),
          onOpenWallet: onOpenWallet,
          actions: actions,
        );
      },
      loading: () => CustomerWalletBalanceCard(
        balance: 0,
        title: l10n.commonWalletBalance,
        customerLabel: l10n.profileMemberCode('-'),
        loading: true,
        loadingLabel: l10n.walletBalanceLoading,
        onOpenWallet: onOpenWallet,
        actions: actions,
      ),
      error: (_, __) => CustomerWalletBalanceCard(
        balance: 0,
        title: l10n.commonWalletBalance,
        customerLabel: l10n.profileMemberCode('-'),
        onOpenWallet: onOpenWallet,
        actions: actions,
      ),
    );
  }
}

class _WalletLedgerSheet extends StatelessWidget {
  const _WalletLedgerSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sheetColor = Color.lerp(
          colorScheme.surfaceContainerHigh,
          colorScheme.surface,
          0.16,
        ) ??
        colorScheme.surfaceContainerHigh;
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.primary),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: sheetColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: CustomerPageBody(
          top: 26,
          bottom: 112,
          child: child,
        ),
      ),
    );
  }
}

class _WalletLedgerLoading extends StatelessWidget {
  const _WalletLedgerLoading();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _walletPanelShadow(colorScheme),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        child: Text(
          context.l10n.walletLedgerLoading,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
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
            color: _walletPanelShadow(colorScheme),
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
                      fontSize: 20,
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
                style: _walletOutlinePillStyle(context),
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
    final colorScheme = Theme.of(context).colorScheme;
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
                      color: colorScheme.onSurface,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.walletRecentLedgerSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: l10n.walletRefreshTooltip,
          onPressed: loading ? null : () => onRefresh(),
          style: IconButton.styleFrom(
            fixedSize: const Size.square(42),
            backgroundColor: _walletPrimaryTint(colorScheme),
            foregroundColor: colorScheme.primary,
            disabledBackgroundColor: _walletPrimaryTint(colorScheme),
            disabledForegroundColor:
                colorScheme.onSurfaceVariant.withValues(alpha: 0.62),
            shape: const CircleBorder(),
          ).copyWith(
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
          icon: const Icon(Icons.refresh, size: 18),
        ),
      ],
    );
  }
}

class _WalletEmptyLedger extends StatelessWidget {
  const _WalletEmptyLedger();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _walletPanelShadow(colorScheme),
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
                  color: _walletPrimaryTint(colorScheme),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 32,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.walletEmptyLedgerTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.walletEmptyLedgerSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _walletPanelBorder(colorScheme)),
        boxShadow: [
          BoxShadow(
            color: _walletPanelShadow(colorScheme).withValues(alpha: 0.72),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            _WalletLedgerTile(entry: entries[index]),
            if (index < entries.length - 1)
              Divider(height: 1, color: _walletPanelBorder(colorScheme)),
          ],
        ],
      ),
    );
  }
}

List<CustomerWalletCardAction> _walletCardActions(
  BuildContext context, {
  VoidCallback? onShowTransactions,
}) {
  final l10n = context.l10n;
  return [
    CustomerWalletCardAction(
      icon: Icons.add,
      label: l10n.homeActionTopup,
      onTap: () => context.go('/topup?back=/my-wallet'),
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
      onTap: onShowTransactions ?? () => context.go('/my-wallet#transactions'),
    ),
  ];
}

class _WalletLedgerTile extends StatelessWidget {
  const _WalletLedgerTile({required this.entry});

  final WalletLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amountColor = entry.isCredit
        ? _walletCreditColor(colorScheme)
        : entry.isDebit
            ? _walletDebitColor(colorScheme)
            : _walletNeutralColor(colorScheme);
    final iconBackground = entry.isCredit
        ? _walletCreditBackground(colorScheme)
        : entry.isDebit
            ? _walletDebitBackground(colorScheme)
            : _walletNeutralBackground(colorScheme);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final amount = _WalletLedgerAmount(
          entry: entry,
          color: amountColor,
          alignEnd: !compact,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: iconBackground,
                  child: Icon(_entryIcon(entry), color: amountColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        walletLedgerTitle(context.l10n, entry),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        walletLedgerSubtitle(context.l10n, entry),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        walletLedgerDate(context.l10n, entry),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
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
          ),
        );
      },
    );
  }

  IconData _entryIcon(WalletLedgerEntry entry) {
    if (entry.isCredit) return Icons.call_received;
    if (entry.isDebit) return Icons.call_made;
    return Icons.account_balance_wallet_outlined;
  }
}

class _WalletLedgerAmount extends StatelessWidget {
  const _WalletLedgerAmount({
    required this.entry,
    required this.color,
    this.alignEnd = true,
  });

  final WalletLedgerEntry entry;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            formatSignedBaht(entry.amount),
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1.15,
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
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
        ),
      ],
    );
  }
}

ButtonStyle _walletOutlinePillStyle(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return OutlinedButton.styleFrom(
    minimumSize: const Size(160, 44),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    foregroundColor: colorScheme.primary,
    side: BorderSide(color: colorScheme.primary),
    shape: const StadiumBorder(),
    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
        ),
  );
}
