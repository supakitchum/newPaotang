import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/customer_operational_error.dart';
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
    final compact = MediaQuery.sizeOf(context).width <= 360;
    final l10n = context.l10n;

    return AppShell(
      title: l10n.purchaseHistoryTitle,
      currentPath: '/profile',
      backPath: '/profile',
      sensitive: true,
      showBottomNavigation: false,
      heroMinHeight: 176,
      heroSheetOverlap: 0,
      heroSheetTopRadius: 22,
      heroContentTopGap: 0,
      heroContent: const SizedBox.shrink(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _PurchaseHistoryContentSheet(
            child: CustomerPageBody(
              top: 28,
              bottom: 56,
              mobileHorizontal: compact ? 16 : 20,
              wideHorizontal: 20,
              includeBottomSafeArea: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loadingInitial)
                    const _PurchaseHistoryLoading()
                  else if (_error.isNotEmpty)
                    _PurchaseHistoryState(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.purchaseHistoryLoadFailed,
                      message: _error,
                      actionLabel: l10n.commonRetry,
                      onAction: _loadInitial,
                    )
                  else if (_orders.isEmpty)
                    _PurchaseHistoryState(
                      icon: Icons.confirmation_number_outlined,
                      title: l10n.purchaseHistoryEmptyTitle,
                      message: l10n.purchaseHistoryEmptySubtitle,
                      actionLabel: l10n.purchaseHistoryBuyButton,
                      onAction: () => context.go('/buy'),
                    )
                  else ...[
                    for (var groupIndex = 0;
                        groupIndex < groups.length;
                        groupIndex++) ...[
                      if (groupIndex > 0) const SizedBox(height: 32),
                      Text(
                        groups[groupIndex].year,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: const Color(0xFF242833),
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                      ),
                      const SizedBox(height: 22),
                      _PurchaseHistoryList(
                        orders: groups[groupIndex].orders,
                        onTap: (order) => context.go(
                          '/purchase-history/${Uri.encodeComponent(order.id)}',
                        ),
                      ),
                    ],
                    if (_currentPage < _lastPage) ...[
                      const SizedBox(height: 28),
                      Center(
                        child: _PurchaseHistoryOutlineButton(
                          label: _loadingMore
                              ? l10n.commonLoadingMore
                              : l10n.commonLoadMore,
                          loading: _loadingMore,
                          onPressed: _loadingMore ? null : _loadMore,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
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
    } catch (error) {
      if (!mounted) return;
      final handled = await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      );
      if (!mounted || handled) return;
      setState(
        () => _error = customerErrorMessage(
          error,
          context.l10n.purchaseHistoryLoadFailedMessage,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _currentPage >= _lastPage) return;
    setState(() {
      _loadingMore = true;
      _error = '';
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
      });
    } catch (error) {
      if (!mounted) return;
      final handled = await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      );
      if (!mounted || handled) return;
      setState(
        () => _error = customerErrorMessage(
          error,
          context.l10n.purchaseHistoryLoadFailedMessage,
        ),
      );
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

class _PurchaseHistoryContentSheet extends StatelessWidget {
  const _PurchaseHistoryContentSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 660),
        child: child,
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
    final compact = MediaQuery.sizeOf(context).width <= 360;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8EDF4))),
      ),
      child: Semantics(
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 116),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  0,
                  topPadding ? 22 : 0,
                  0,
                  22,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    context.l10n.purchaseHistoryOrderTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleMedium?.copyWith(
                                      color: const Color(0xFF252A31),
                                      fontSize: compact ? 18 : 20,
                                      fontWeight: FontWeight.w900,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                _PurchaseHistoryPill(
                                  label:
                                      context.l10n.purchaseHistoryDigitalTicket,
                                  compact: compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.purchaseHistoryDrawDate(
                                localizedPurchaseDrawDate(context, order),
                              ),
                              style: textTheme.titleSmall?.copyWith(
                                color: const Color(0xFF626A73),
                                fontSize: compact ? 18 : 20,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              localizedPurchaseTransactionDate(context, order),
                              style: textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF8A929B),
                                fontSize: compact ? 15 : 17,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: compact ? 10 : 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 92),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _PurchaseHistoryAmount(
                              value: order.total,
                              compact: compact,
                            ),
                            Expanded(
                              child: Center(
                                child: Icon(
                                  Icons.chevron_right,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 34,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseHistoryPill extends StatelessWidget {
  const _PurchaseHistoryPill({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 112 : 128),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFEEE7FF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF8762D6),
                  fontSize: compact ? 13 : 15,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseHistoryAmount extends StatelessWidget {
  const _PurchaseHistoryAmount({required this.value, required this.compact});

  final double value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: localizedPurchaseMoneyAmount(context, value),
            style: TextStyle(
              fontSize: compact ? 19 : 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const TextSpan(text: ' '),
          TextSpan(
            text: context.l10n.commonBahtSuffix,
            style: TextStyle(
              fontSize: compact ? 16 : 19,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      maxLines: 1,
      textAlign: TextAlign.right,
      style: const TextStyle(color: Color(0xFF2A2F35), height: 1.1),
    );
  }
}

class _PurchaseHistoryLoading extends StatelessWidget {
  const _PurchaseHistoryLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        context.l10n.purchaseHistoryLoading,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF8A8F98),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _PurchaseHistoryState extends StatelessWidget {
  const _PurchaseHistoryState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 56),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEEF7FF),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF242833),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF596474),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 20),
          _PurchaseHistoryPrimaryButton(
            label: actionLabel,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

class _PurchaseHistoryPrimaryButton extends StatelessWidget {
  const _PurchaseHistoryPrimaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryActionStart(primary),
            AppTheme.primaryActionEnd(primary),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryActionEnd(primary).withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size(148, 47),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        child: Text(label),
      ),
    );
  }
}

class _PurchaseHistoryOutlineButton extends StatelessWidget {
  const _PurchaseHistoryOutlineButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryOutlineText(primary),
        disabledForegroundColor: const Color(0xFF8A8F98),
        backgroundColor: loading ? const Color(0xFFF2F4F7) : Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: const StadiumBorder(),
        side: BorderSide(
          color: loading
              ? const Color(0xFFCBD4DF)
              : AppTheme.primaryOutlineBorder(primary),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ).copyWith(
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      child: Text(label),
    );
  }
}
