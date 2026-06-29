import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
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
      sensitive: true,
      child: RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            CustomerPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PurchaseHistoryHeader(onBuy: () => context.go('/buy')),
                  const SizedBox(height: 12),
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
                    for (final group in groups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
                        child: Text(
                          group.year,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      for (final order in group.orders)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _PurchaseHistoryTile(
                            order: order,
                            onTap: () =>
                                context.go('/purchase-history/${order.id}'),
                          ),
                        ),
                    ],
                    if (_currentPage < _lastPage)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: OutlinedButton.icon(
                          onPressed: _loadingMore ? null : _loadMore,
                          icon: _loadingMore
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
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
          ],
        ),
      ),
    );
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _error = '';
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
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(purchaseHistoryRepositoryProvider)
          .list(page: _currentPage + 1);
      if (!mounted) return;
      setState(() {
        _orders.addAll(page.items);
        _currentPage = page.currentPage;
        _lastPage = page.lastPage;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.purchaseHistoryLoadMoreFailed)),
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

class _PurchaseYearGroup {
  const _PurchaseYearGroup(this.year, this.orders);

  final String year;
  final List<PurchaseHistoryOrder> orders;
}

class _PurchaseHistoryHeader extends StatelessWidget {
  const _PurchaseHistoryHeader({required this.onBuy});

  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.receipt_long_outlined),
        ),
        title: Text(
          l10n.purchaseHistoryHeaderTitle,
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(l10n.purchaseHistoryHeaderSubtitle),
        trailing: IconButton(
          tooltip: l10n.purchaseHistoryBuyTooltip,
          onPressed: onBuy,
          icon: const Icon(Icons.confirmation_number_outlined),
        ),
      ),
    );
  }
}

class _PurchaseHistoryTile extends StatelessWidget {
  const _PurchaseHistoryTile({required this.order, required this.onTap});

  final PurchaseHistoryOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          context.l10n.purchaseHistoryOrderTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Chip(
                          label:
                              Text(context.l10n.purchaseHistoryDigitalTicket),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.purchaseHistoryDrawDate(
                        localizedPurchaseDrawDate(context, order),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizedPurchaseTransactionDate(context, order),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatBaht(order.total),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    context.l10n.purchaseHistoryTicketCount(order.ticketCount),
                  ),
                  const SizedBox(height: 8),
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

class _PurchaseHistoryEmpty extends StatelessWidget {
  const _PurchaseHistoryEmpty({required this.onBuy});

  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
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
              style: TextStyle(color: Colors.grey.shade700),
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
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
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
    return Card(
      margin: EdgeInsets.zero,
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
