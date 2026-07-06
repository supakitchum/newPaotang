import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/tenant_brand_header.dart';
import '../data/purchase_history_models.dart';
import '../data/purchase_history_repository.dart';
import 'purchase_history_localization.dart';

class PurchaseHistoryDetailScreen extends ConsumerWidget {
  const PurchaseHistoryDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(purchaseHistoryDetailProvider(orderId));
    final l10n = context.l10n;

    return AppShell(
      title: l10n.purchaseHistoryDetailTitle,
      currentPath: '/profile',
      sensitive: true,
      child: _PurchaseReceiptBackground(
        child: ListView(
          children: [
            CustomerPageBody(
              maxWidth: 520,
              top: 24,
              mobileHorizontal: 20,
              wideHorizontal: 28,
              child: AsyncStateView(
                value: order,
                data: (item) => _PurchaseReceipt(order: item),
                empty: const _PurchaseReceiptEmpty(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseReceiptBackground extends StatelessWidget {
  const _PurchaseReceiptBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    final secondary = colorScheme.secondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary,
            Color.lerp(primary, secondary, 0.56) ?? secondary,
          ],
        ),
      ),
      child: child,
    );
  }
}

class _PurchaseReceipt extends StatelessWidget {
  const _PurchaseReceipt({required this.order});

  final PurchaseHistoryOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration:
              _purchaseHistoryDetailSurfaceDecoration(context, radius: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ReceiptBrand(),
                const SizedBox(height: 26),
                Text(
                  l10n.purchaseHistoryReceiptTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.purchaseHistoryReceiptSubtitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 26),
                _ReceiptSection(
                  rows: [
                    _ReceiptRow(
                      l10n.purchaseHistoryTicketCountLabel,
                      l10n.purchaseHistoryTicketCount(order.ticketCount),
                      highlighted: true,
                    ),
                    _ReceiptRow(
                      l10n.purchaseHistoryDrawDateLabel,
                      localizedPurchaseDrawDate(context, order),
                      highlighted: true,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ReceiptSection(
                  rows: [
                    _ReceiptRow(
                      l10n.purchaseHistoryPayeeLabel,
                      localizedPurchaseStoreName(context, order),
                    ),
                    _ReceiptRow(
                      l10n.purchaseHistoryPaymentChannelLabel,
                      _paymentChannelText(context, order),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _TotalRow(order: order),
                const SizedBox(height: 22),
                _ReceiptMeta(order: order),
              ],
            ),
          ),
        ),
        if (order.tickets.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TicketList(order: order),
        ],
      ],
    );
  }

  String _paymentChannelText(BuildContext context, PurchaseHistoryOrder order) {
    final reference = order.maskedPaymentReference;
    final channel = localizedPurchasePaymentChannel(order);
    if (reference.isEmpty) return channel;
    return '$channel\n$reference';
  }
}

class _ReceiptBrand extends ConsumerWidget {
  const _ReceiptBrand();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final productLabel = ref
            .watch(mobileBootstrapProvider)
            .valueOrNull
            ?.lotteryProductLabel
            .trim() ??
        '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const TenantBrandHeader(
          size: 58,
          maxWidth: 58,
          showName: false,
          icon: Icons.receipt_long_outlined,
        ),
        if (productLabel.isNotEmpty) ...[
          const SizedBox(width: 18),
          SizedBox(
            height: 38,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: colorScheme.outlineVariant,
            ),
          ),
          const SizedBox(width: 18),
          Text(
            productLabel,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
          ),
        ],
      ],
    );
  }
}

class _ReceiptSection extends StatelessWidget {
  const _ReceiptSection({required this.rows});

  final List<_ReceiptRow> rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Divider(height: 1, color: colorScheme.outlineVariant),
        const SizedBox(height: 18),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: row,
          ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(this.label, this.value, {this.highlighted = false});

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: textTheme.titleSmall?.copyWith(
              color: highlighted ? colorScheme.primary : colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.order});

  final PurchaseHistoryOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            l10n.purchaseHistoryTotalLabel,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        Text(
          formatBaht(order.total),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
        ),
      ],
    );
  }
}

class _ReceiptMeta extends StatelessWidget {
  const _ReceiptMeta({required this.order});

  final PurchaseHistoryOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.purchaseHistoryTransactionAt(
                localizedPurchaseTransactionDate(context, order),
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 7),
            Text(
              l10n.purchaseHistoryReference(order.displayReference),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  const _TicketList({required this.order});

  final PurchaseHistoryOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: _purchaseHistoryDetailSurfaceDecoration(context, radius: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.purchaseHistoryTicketListTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ticket in order.tickets)
                  _PurchaseTicketPill(number: ticket.number),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseReceiptEmpty extends StatelessWidget {
  const _PurchaseReceiptEmpty();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _purchaseHistoryDetailSurfaceDecoration(context, radius: 14),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          context.l10n.purchaseHistoryDetailEmpty,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _PurchaseTicketPill extends StatelessWidget {
  const _PurchaseTicketPill({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: 15,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              number,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _purchaseHistoryDetailSurfaceDecoration(
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
