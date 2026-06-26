import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../data/reward_claim_models.dart';
import '../data/reward_claim_repository.dart';
import 'claim_realtime_monitor.dart';
import 'reward_claim_localization.dart';

class RewardClaimDetailScreen extends ConsumerWidget {
  const RewardClaimDetailScreen({required this.claimId, super.key});

  final String claimId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(
      rewardClaimRealtimeTickProvider,
      (_, __) => ref.invalidate(rewardClaimDetailProvider(claimId)),
    );
    final claim = ref.watch(rewardClaimDetailProvider(claimId));
    final l10n = context.l10n;

    return AppShell(
      title: l10n.rewardClaimDetailTitle,
      currentPath: '/my-wallet',
      sensitive: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncStateView(
            value: claim,
            data: (item) => _RewardClaimReceipt(claim: item),
            empty: const _RewardClaimEmptyDetail(),
          ),
        ],
      ),
    );
  }
}

class _RewardClaimReceipt extends StatelessWidget {
  const _RewardClaimReceipt({required this.claim});

  final RewardClaimItem claim;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(claim);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Text('GLO')),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.ticketLabelGovernmentLottery,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                _StatusBadge(
                  label: rewardClaimStatusLabel(context.l10n, claim),
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _NoticeBox(
              text: rewardClaimTransferNote(context.l10n, claim),
              color: statusColor,
            ),
            const SizedBox(height: 16),
            _ReceiptSection(
              rows: [
                _ReceiptRow(
                  context.l10n.ticketLabelRecipient,
                  rewardClaimCustomerName(context.l10n, claim),
                  highlighted: true,
                ),
                _ReceiptRow(
                  context.l10n.ticketLabelPayoutChannel,
                  rewardClaimPayoutChannelText(context.l10n, claim),
                  highlighted: true,
                ),
                _ReceiptRow(
                  context.l10n.rewardClaimMethodLabel,
                  context.l10n.rewardClaimManualMethod,
                ),
                _ReceiptRow(
                  context.l10n.rewardClaimStatusLabel,
                  rewardClaimStatusLabel(context.l10n, claim),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ReceiptSection(
              rows: [
                _ReceiptRow(
                  context.l10n.rewardClaimDrawDateLabel,
                  rewardClaimDrawDateText(context.l10n, claim.ticket),
                ),
                _ReceiptRow(
                  context.l10n.ticketLabelLotteryNumber,
                  claim.ticket?.number ?? '-',
                ),
                _ReceiptRow(
                  context.l10n.ticketLabelPrize,
                  rewardClaimPrizeLines(context.l10n, claim),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MoneySection(claim: claim),
            if (claim.adminNote.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _AdminNote(note: claim.adminNote, rejected: claim.isRejected),
            ],
          ],
        ),
      ),
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
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade700),
          ),
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

class _MoneySection extends StatelessWidget {
  const _MoneySection({required this.claim});

  final RewardClaimItem claim;

  @override
  Widget build(BuildContext context) {
    final taxAmount = claim.prizeAmount * 0.005;
    final feeAmount = claim.prizeAmount * 0.01;
    final l10n = context.l10n;

    return Column(
      children: [
        const Divider(height: 1),
        const SizedBox(height: 10),
        _MoneyRow(l10n.ticketLabelPrizeAmount, formatBaht(claim.prizeAmount)),
        _MoneyRow(
          l10n.rewardClaimTaxLabel,
          l10n.rewardClaimZeroBaht,
          helper: l10n.rewardClaimWaived(formatBaht(taxAmount)),
          positive: true,
        ),
        _MoneyRow(
          l10n.rewardClaimFeeLabel,
          l10n.rewardClaimZeroBaht,
          helper: l10n.rewardClaimWaived(formatBaht(feeAmount)),
          positive: true,
        ),
        const Divider(height: 18),
        _MoneyRow(
          l10n.ticketLabelNetAmount,
          formatBaht(claim.prizeAmount),
          total: true,
        ),
      ],
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow(
    this.label,
    this.value, {
    this.helper = '',
    this.positive = false,
    this.total = false,
  });

  final String label;
  final String value;
  final String helper;
  final bool positive;
  final bool total;

  @override
  Widget build(BuildContext context) {
    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w900,
          color: positive ? Colors.green.shade700 : null,
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: total
                  ? const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: total ? valueStyle : valueStyle),
                if (helper.isNotEmpty)
                  Text(
                    helper,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _AdminNote extends StatelessWidget {
  const _AdminNote({required this.note, required this.rejected});

  final String note;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final color = rejected ? Colors.red.shade700 : Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.08),
      ),
      child: Text(note, style: TextStyle(color: color)),
    );
  }
}

class _RewardClaimEmptyDetail extends StatelessWidget {
  const _RewardClaimEmptyDetail();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(context.l10n.rewardClaimEmptyDetail),
      ),
    );
  }
}

Color _statusColor(RewardClaimItem claim) {
  if (claim.isPaid) return Colors.green.shade700;
  if (claim.isRejected) return Colors.red.shade700;
  return Colors.orange.shade800;
}
