import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncStateView(
            value: order,
            data: (item) => _PurchaseReceipt(order: item),
            empty: const _PurchaseReceiptEmpty(),
          ),
        ],
      ),
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
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ReceiptBrand(),
                const SizedBox(height: 18),
                Text(
                  l10n.purchaseHistoryReceiptTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.purchaseHistoryReceiptSubtitle,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
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
                const SizedBox(height: 14),
                _TotalRow(order: order),
                const SizedBox(height: 12),
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

class _ReceiptBrand extends StatelessWidget {
  const _ReceiptBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'GLO',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
        ),
        Container(
          height: 38,
          width: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: Colors.grey.shade300,
        ),
        Text(
          'L6',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _ReceiptSection extends StatelessWidget {
  const _ReceiptSection({required this.rows});

  final List<_ReceiptRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1),
        const SizedBox(height: 10),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: highlighted ? Theme.of(context).colorScheme.primary : null,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            l10n.purchaseHistoryTotalLabel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          formatBaht(order.total),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
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
            ),
            const SizedBox(height: 4),
            Text(l10n.purchaseHistoryReference(order.displayReference)),
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
    return Card(
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
                  Chip(
                    label: Text(ticket.number),
                    avatar: const Icon(Icons.confirmation_number_outlined),
                    visualDensity: VisualDensity.compact,
                  ),
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
    return Card(
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
