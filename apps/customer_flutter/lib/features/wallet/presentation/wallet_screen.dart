import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
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
    colorScheme.shadow.withValues(alpha: 0.06);

enum _WalletLedgerFilter { latest, incoming, outgoing }

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _transactionsKey = GlobalKey();
  bool _transactionsScrollScheduled = false;
  String _lastHandledFragment = '';
  _WalletLedgerFilter _selectedFilter = _WalletLedgerFilter.latest;

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
    listenForCustomerOperationalError<WalletSummary>(
      ref: ref,
      context: context,
      provider: walletSummaryProvider,
    );
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
      showBottomNavigation: true,
      heroContent: const SizedBox.shrink(),
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _WalletPageSheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WalletHeroCard(
                  summary: summary,
                  onOpenWallet: () => context.go('/my-wallet'),
                  actions: _walletCardActions(
                    context,
                    onShowTransactions: _openTransactions,
                  ),
                ),
                const SizedBox(height: 28),
                Column(
                  key: _transactionsKey,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WalletLedgerHeader(
                      loading: summary.isLoading,
                      onRefresh: refreshWallet,
                    ),
                    const SizedBox(height: 14),
                    _WalletLedgerFilterTabs(
                      selected: _selectedFilter,
                      onSelected: (filter) {
                        setState(() => _selectedFilter = filter);
                      },
                    ),
                    const SizedBox(height: 16),
                    summary.when(
                      data: (data) {
                        if (data.ledgerLoadFailed) {
                          return _WalletLedgerLoadFailed(
                            message: data.ledgerErrorMessage,
                            onRetry: refreshWallet,
                          );
                        }
                        return Column(
                          children: [
                            for (final filter in _WalletLedgerFilter.values)
                              Offstage(
                                offstage: filter != _selectedFilter,
                                child: _WalletLedgerFeed(
                                  key: ValueKey(
                                    'wallet-ledger-feed-${filter.name}',
                                  ),
                                  filter: filter,
                                  active: filter == _selectedFilter,
                                  seedEntries: data.ledger,
                                  seedNextCursor: data.ledgerNextCursor,
                                  seedHasMore: data.ledgerHasMore,
                                  walletName: data.primaryWallet?.name ?? '',
                                ),
                              ),
                          ],
                        );
                      },
                      loading: () => const _WalletLedgerLoading(),
                      error: (_, __) => _WalletLedgerLoadFailed(
                        message: l10n.walletLedgerLoadFailedMessage,
                        onRetry: refreshWallet,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on _WalletLedgerFilter {
  WalletLedgerDirection get direction => switch (this) {
    _WalletLedgerFilter.latest => WalletLedgerDirection.all,
    _WalletLedgerFilter.incoming => WalletLedgerDirection.incoming,
    _WalletLedgerFilter.outgoing => WalletLedgerDirection.outgoing,
  };
}

List<WalletLedgerEntry> _filterWalletLedger(
  List<WalletLedgerEntry> entries,
  _WalletLedgerFilter filter,
) {
  return switch (filter) {
    _WalletLedgerFilter.latest => entries,
    _WalletLedgerFilter.incoming =>
      entries.where((entry) => entry.isCredit).toList(growable: false),
    _WalletLedgerFilter.outgoing =>
      entries.where((entry) => entry.isDebit).toList(growable: false),
  };
}

class _WalletPageSheet extends StatelessWidget {
  const _WalletPageSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('wallet-content-sheet'),
      decoration: const BoxDecoration(
        color: AppTheme.appWalletSheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: CustomerPageBody(
        top: 16,
        bottom: 112,
        mobileHorizontal: 16,
        wideHorizontal: 16,
        minViewportHeight: true,
        child: child,
      ),
    );
  }
}

class _WalletLedgerFilterTabs extends StatelessWidget {
  const _WalletLedgerFilterTabs({
    required this.selected,
    required this.onSelected,
  });

  final _WalletLedgerFilter selected;
  final ValueChanged<_WalletLedgerFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('wallet-ledger-filter-tabs'),
      decoration: BoxDecoration(
        color: _walletPrimaryTint(Theme.of(context).colorScheme),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final filter in _WalletLedgerFilter.values)
              Expanded(
                child: _WalletLedgerFilterTab(
                  filter: filter,
                  selected: selected == filter,
                  onPressed: () => onSelected(filter),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WalletLedgerFilterTab extends StatelessWidget {
  const _WalletLedgerFilterTab({
    required this.filter,
    required this.selected,
    required this.onPressed,
  });

  final _WalletLedgerFilter filter;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final label = switch (filter) {
      _WalletLedgerFilter.latest => l10n.walletFilterLatest,
      _WalletLedgerFilter.incoming => l10n.walletFilterIncoming,
      _WalletLedgerFilter.outgoing => l10n.walletFilterOutgoing,
    };
    final radius = BorderRadius.circular(11);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('wallet-filter-${filter.name}'),
          onTap: onPressed,
          borderRadius: radius,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colorScheme.primary : Colors.transparent,
              borderRadius: radius,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? colorScheme.onPrimary : colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _walletCustomerLabel(CustomerLocalizations l10n, String customerNo) {
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
            ? ref
                  .watch(customerProfileSettingsProvider)
                  .maybeWhen(
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

class _WalletLedgerFeed extends ConsumerStatefulWidget {
  const _WalletLedgerFeed({
    required this.filter,
    required this.active,
    required this.seedEntries,
    required this.seedNextCursor,
    required this.seedHasMore,
    required this.walletName,
    super.key,
  });

  final _WalletLedgerFilter filter;
  final bool active;
  final List<WalletLedgerEntry> seedEntries;
  final String seedNextCursor;
  final bool seedHasMore;
  final String walletName;

  @override
  ConsumerState<_WalletLedgerFeed> createState() => _WalletLedgerFeedState();
}

class _WalletLedgerFeedState extends ConsumerState<_WalletLedgerFeed> {
  List<WalletLedgerEntry> _entries = const [];
  String _nextCursor = '';
  bool _hasMore = false;
  bool _initialLoaded = false;
  bool _initialLoading = false;
  bool _loadingMore = false;
  String _initialError = '';
  String _loadMoreError = '';
  bool _loadScheduled = false;

  @override
  void initState() {
    super.initState();
    _resetFromSeed();
    _scheduleInitialLoad();
  }

  @override
  void didUpdateWidget(covariant _WalletLedgerFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    final seedChanged =
        !identical(oldWidget.seedEntries, widget.seedEntries) ||
        oldWidget.seedNextCursor != widget.seedNextCursor ||
        oldWidget.seedHasMore != widget.seedHasMore;
    if (seedChanged) _resetFromSeed();
    if (seedChanged || (!oldWidget.active && widget.active)) {
      _scheduleInitialLoad();
    }
  }

  void _resetFromSeed() {
    final seedIsComplete =
        widget.filter == _WalletLedgerFilter.latest || !widget.seedHasMore;
    _entries = seedIsComplete
        ? _filterWalletLedger(widget.seedEntries, widget.filter)
        : const [];
    _nextCursor = widget.filter == _WalletLedgerFilter.latest
        ? widget.seedNextCursor
        : '';
    _hasMore =
        widget.filter == _WalletLedgerFilter.latest &&
        widget.seedHasMore &&
        widget.seedNextCursor.trim().isNotEmpty;
    _initialLoaded = seedIsComplete;
    _initialLoading = false;
    _loadingMore = false;
    _initialError = '';
    _loadMoreError = '';
  }

  void _scheduleInitialLoad() {
    if (!widget.active || _initialLoaded || _initialLoading || _loadScheduled) {
      return;
    }
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (!mounted || !widget.active || _initialLoaded || _initialLoading) {
        return;
      }
      _loadInitial();
    });
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _initialError = '';
    });
    try {
      final page = await ref
          .read(walletRepositoryProvider)
          .ledgerPage(direction: widget.filter.direction);
      if (!mounted) return;
      setState(() {
        _entries = page.entries;
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore && page.nextCursor.trim().isNotEmpty;
        _initialLoaded = true;
        _initialLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _initialError = customerErrorMessage(
          error,
          context.l10n.walletLedgerLoadFailedMessage,
        );
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _nextCursor.trim().isEmpty) return;
    setState(() {
      _loadingMore = true;
      _loadMoreError = '';
    });
    try {
      final page = await ref
          .read(walletRepositoryProvider)
          .ledgerPage(cursor: _nextCursor, direction: widget.filter.direction);
      if (!mounted) return;
      final knownIds = _entries
          .map((entry) => entry.id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      final additions = page.entries.where((entry) {
        final id = entry.id.trim();
        return id.isEmpty || knownIds.add(id);
      });
      setState(() {
        _entries = [..._entries, ...additions];
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore && page.nextCursor.trim().isNotEmpty;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _loadMoreError = customerErrorMessage(
          error,
          context.l10n.walletLedgerLoadFailedMessage,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading || !_initialLoaded && _initialError.isEmpty) {
      return const _WalletLedgerLoading();
    }
    if (_initialError.isNotEmpty) {
      return _WalletLedgerLoadFailed(
        message: _initialError,
        onRetry: _loadInitial,
      );
    }
    if (_entries.isEmpty) {
      return _WalletEmptyLedger(filter: widget.filter);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WalletLedgerList(entries: _entries, walletName: widget.walletName),
        if (_hasMore || _loadingMore || _loadMoreError.isNotEmpty) ...[
          const SizedBox(height: 14),
          _WalletLedgerLoadMore(
            loading: _loadingMore,
            errorMessage: _loadMoreError,
            onPressed: _loadMore,
          ),
        ],
      ],
    );
  }
}

class _WalletLedgerLoadMore extends StatelessWidget {
  const _WalletLedgerLoadMore({
    required this.loading,
    required this.errorMessage,
    required this.onPressed,
  });

  final bool loading;
  final String errorMessage;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (errorMessage.isNotEmpty) ...[
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton(
          key: const ValueKey('wallet-ledger-load-more'),
          style: _walletOutlinePillStyle(context),
          onPressed: loading ? null : () => onPressed(),
          child: loading
              ? CustomerLoadingMark(
                  width: 26,
                  height: 16,
                  color: colorScheme.primary,
                  trackColor: colorScheme.primary.withValues(alpha: 0.18),
                  semanticLabel: context.l10n.walletLedgerLoading,
                )
              : Text(
                  errorMessage.isEmpty
                      ? context.l10n.commonLoadMore
                      : context.l10n.commonRetry,
                ),
        ),
      ],
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
            blurRadius: 16,
            offset: const Offset(0, 5),
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
  const _WalletLedgerLoadFailed({required this.message, required this.onRetry});

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
            blurRadius: 16,
            offset: const Offset(0, 5),
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
  const _WalletLedgerHeader({required this.loading, required this.onRefresh});

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
          style:
              IconButton.styleFrom(
                fixedSize: const Size.square(42),
                backgroundColor: _walletPrimaryTint(colorScheme),
                foregroundColor: colorScheme.primary,
                disabledBackgroundColor: _walletPrimaryTint(colorScheme),
                disabledForegroundColor: colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.62),
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
  const _WalletEmptyLedger({this.filter = _WalletLedgerFilter.latest});

  final _WalletLedgerFilter filter;

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
            blurRadius: 16,
            offset: const Offset(0, 5),
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
                switch (filter) {
                  _WalletLedgerFilter.latest =>
                    context.l10n.walletEmptyLedgerTitle,
                  _WalletLedgerFilter.incoming =>
                    context.l10n.walletEmptyIncoming,
                  _WalletLedgerFilter.outgoing =>
                    context.l10n.walletEmptyOutgoing,
                },
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
  const _WalletLedgerList({required this.entries, required this.walletName});

  final List<WalletLedgerEntry> entries;
  final String walletName;

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
            color: _walletPanelShadow(colorScheme),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            _WalletLedgerTile(entry: entries[index], walletName: walletName),
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
      onTap: () => context.push('/topup?back=/my-wallet'),
    ),
    CustomerWalletCardAction(
      icon: Icons.confirmation_number_outlined,
      label: l10n.homeActionTickets,
      onTap: () => context.push('/tickets'),
    ),
    CustomerWalletCardAction(
      icon: Icons.payments_outlined,
      label: l10n.homeActionClaim,
      onTap: () => context.push('/reward-claims'),
    ),
    CustomerWalletCardAction(
      icon: Icons.history,
      label: l10n.homeActionHistory,
      onTap: onShowTransactions ?? () => context.go('/my-wallet#transactions'),
    ),
  ];
}

class _WalletLedgerTile extends StatelessWidget {
  const _WalletLedgerTile({required this.entry, required this.walletName});

  final WalletLedgerEntry entry;
  final String walletName;

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
        final compact = MediaQuery.sizeOf(context).width <= 360;
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
                        walletLedgerTitle(
                          context.l10n,
                          entry,
                          walletName: walletName,
                        ),
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
                      if (compact) ...[const SizedBox(height: 6), amount],
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
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
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
          context.l10n.walletBalanceAfter(formatBaht(entry.balanceAfter)),
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
    textStyle: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
  );
}
