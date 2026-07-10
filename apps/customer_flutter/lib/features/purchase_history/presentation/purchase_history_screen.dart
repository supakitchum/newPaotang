import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/purchase_history_models.dart';
import '../data/purchase_history_repository.dart';
import 'purchase_history_localization.dart';

class PurchaseHistoryScreen extends ConsumerStatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  ConsumerState<PurchaseHistoryScreen> createState() =>
      _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends ConsumerState<PurchaseHistoryScreen> {
  final _orders = <PurchaseHistoryOrder>[];
  int _currentPage = 1;
  int _lastPage = 1;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  String _error = '';
  String _loadMoreError = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadInitial);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupOrders(_orders);
    final l10n = context.l10n;
    return AppShell(
      title: l10n.purchaseHistoryTitle,
      currentPath: '/profile',
      backPath: '/profile',
      sensitive: true,
      showBottomNavigation: false,
      heroMinHeight: 176,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      heroContent: const SizedBox.shrink(),
      child: RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            CustomerPageBody(
              maxWidth: 560,
              top: 0,
              mobileHorizontal: 0,
              wideHorizontal: 28,
              child: _PurchaseHistoryContentSheet(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loadingInitial)
                      const _PurchaseHistoryLoading()
                    else if (_error.isNotEmpty)
                      _PurchaseHistoryError(
                        message: _error,
                        onRetry: _loadInitial,
                      )
                    else if (_orders.isEmpty)
                      _PurchaseHistoryEmpty(onBuy: () => context.go('/buy'))
                    else ...[
                      for (var groupIndex = 0;
                          groupIndex < groups.length;
                          groupIndex++) ...[
                        if (groupIndex > 0) const SizedBox(height: 32),
                        Text(
                          groups[groupIndex].year,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                        ),
                        const SizedBox(height: 22),
                        _PurchaseHistoryList(
                          orders: groups[groupIndex].orders,
                          onTap: (order) =>
                              context.go('/purchase-history/${order.id}'),
                        ),
                      ],
                      if (_loadMoreError.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _PurchaseHistoryInlineNotice(
                          message: _loadMoreError,
                          actionLabel: l10n.commonRetry,
                          onAction: _loadingMore ? null : _loadMore,
                        ),
                      ],
                      if (_currentPage < _lastPage)
                        Padding(
                          padding: const EdgeInsets.only(top: 22),
                          child: OutlinedButton.icon(
                            onPressed: _loadingMore ? null : _loadMore,
                            icon: _loadingMore
                                ? CustomerLoadingMark(
                                    width: 18,
                                    height: 14,
                                    semanticLabel: l10n.commonLoadingMore,
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
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _error = '';
      _loadMoreError = '';
    });
    try {
      final page = await ref.read(purchaseHistoryRepositoryProvider).list();
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(page.items);
        _currentPage = page.currentPage;
        _lastPage = page.lastPage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = context.l10n.purchaseHistoryLoadFailed);
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _currentPage >= _lastPage) return;
    setState(() {
      _loadingMore = true;
      _loadMoreError = '';
    });
    try {
      final page = await ref
          .read(purchaseHistoryRepositoryProvider)
          .list(page: _currentPage + 1);
      if (!mounted) return;
      setState(() {
        _orders.addAll(page.items);
        _currentPage = page.currentPage;
        _lastPage = page.lastPage;
        _loadMoreError = '';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _loadMoreError = context.l10n.purchaseHistoryLoadMoreFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<_PurchaseYearGroup> _groupOrders(List<PurchaseHistoryOrder> orders) {
    final grouped = <String, List<PurchaseHistoryOrder>>{};
    for (final order in orders) {
      grouped
          .putIfAbsent(localizedPurchaseYear(context, order), () => [])
          .add(order);
    }
    return grouped.entries
        .map((entry) => _PurchaseYearGroup(entry.key, entry.value))
        .toList(growable: false);
  }
}

class _PurchaseHistoryInlineNotice extends StatelessWidget {
  const _PurchaseHistoryInlineNotice({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.40),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.24),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PurchaseYearGroup {
  const _PurchaseYearGroup(this.year, this.orders);

  final String year;
  final List<PurchaseHistoryOrder> orders;
}

class _PurchaseHistoryContentSheet extends StatelessWidget {
  const _PurchaseHistoryContentSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 660),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 56),
          child: child,
        ),
      ),
    );
  }
}

class _PurchaseHistoryList extends StatelessWidget {
  const _PurchaseHistoryList({required this.orders, required this.onTap});

  final List<PurchaseHistoryOrder> orders;
  final ValueChanged<PurchaseHistoryOrder> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < orders.length; index++)
          _PurchaseHistoryTile(
            order: orders[index],
            topPadding: index > 0,
            onTap: () => onTap(orders[index]),
          ),
      ],
    );
  }
}

class _PurchaseHistoryTile extends StatelessWidget {
  const _PurchaseHistoryTile({
    required this.order,
    required this.onTap,
    required this.topPadding,
  });

  final PurchaseHistoryOrder order;
  final VoidCallback onTap;
  final bool topPadding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(0, topPadding ? 22 : 0, 0, 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 9,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            context.l10n.purchaseHistoryOrderTitle,
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          _PurchaseHistoryPill(
                            label: context.l10n.purchaseHistoryDigitalTicket,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.purchaseHistoryDrawDate(
                          localizedPurchaseDrawDate(context, order),
                        ),
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        localizedPurchaseTransactionDate(context, order),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.78),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 92),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatBaht(order.total),
                        textAlign: TextAlign.right,
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n
                            .purchaseHistoryTicketCount(order.ticketCount),
                        textAlign: TextAlign.right,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.78),
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Icon(
                        Icons.chevron_right,
                        color: colorScheme.primary,
                        size: 34,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseHistoryPill extends StatelessWidget {
  const _PurchaseHistoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(
          colorScheme.primaryContainer,
          colorScheme.surface,
          0.38,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
        ),
      ),
    );
  }
}

class _PurchaseHistoryEmpty extends StatelessWidget {
  const _PurchaseHistoryEmpty({required this.onBuy});

  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: _purchaseHistorySurfaceDecoration(context, radius: 14),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.purchaseHistoryEmptyTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.purchaseHistoryEmptySubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onBuy,
              icon: const Icon(Icons.confirmation_number_outlined),
              label: Text(l10n.purchaseHistoryBuyButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseHistoryLoading extends StatelessWidget {
  const _PurchaseHistoryLoading();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _purchaseHistorySurfaceDecoration(context, radius: 14),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: CustomerLoadingMark(
            width: 46,
            height: 28,
            semanticLabel: context.l10n.commonLoadingData,
          ),
        ),
      ),
    );
  }
}

class _PurchaseHistoryError extends StatelessWidget {
  const _PurchaseHistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: _purchaseHistorySurfaceDecoration(context, radius: 14),
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

BoxDecoration _purchaseHistorySurfaceDecoration(
  BuildContext context, {
  required double radius,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: colorScheme.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
    boxShadow: [
      BoxShadow(
        color: colorScheme.primary.withValues(alpha: 0.08),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}
