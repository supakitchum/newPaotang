import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/tenant_brand_header.dart';
import '../data/reward_claim_models.dart';
import '../data/reward_claim_repository.dart';
import 'claim_realtime_monitor.dart';
import 'reward_claim_error_message.dart';
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
      currentPath: '/reward-claims',
      backPath: '/reward-claims',
      sensitive: true,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          CustomerPageBody(
            maxWidth: 640,
            top: 12,
            mobileHorizontal: 10,
            wideHorizontal: 10,
            child: claim.when(
              data: (item) => _RewardClaimReceipt(claim: item),
              loading: () => _RewardClaimDetailState(
                message: l10n.rewardClaimDetailLoading,
              ),
              error: (error, __) => _RewardClaimDetailState(
                message: rewardClaimErrorMessage(
                  error,
                  l10n.rewardClaimDetailLoadFailed,
                ),
                error: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardClaimReceipt extends ConsumerWidget {
  const _RewardClaimReceipt({required this.claim});

  final RewardClaimItem claim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(claim);
    final receiptMark = ref.watch(mobileBootstrapProvider).maybeWhen(
          data: (data) => data.ticketImageWatermark.trim(),
          orElse: () => '',
        );
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (receiptMark.isEmpty)
                  const TenantBrandHeader(
                    showName: false,
                    size: 42,
                    icon: Icons.emoji_events_outlined,
                  )
                else
                  _ReceiptBrandMark(label: receiptMark),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.ticketLabelGovernmentLottery,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF111827),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            _ReceiptSection(
              rows: [
                _ReceiptRow(
                  context.l10n.ticketLabelRecipient,
                  rewardClaimCustomerName(context.l10n, claim),
                  highlighted: true,
                ),
                _ReceiptRow(
                  context.l10n.rewardClaimPayoutChannelLabel,
                  rewardClaimPayoutChannelText(context.l10n, claim),
                  highlighted: true,
                ),
                _ReceiptRow(
                  context.l10n.rewardClaimMethodLabel,
                  context.l10n.rewardClaimManualMethod,
                  highlighted: true,
                ),
                _ReceiptRow(
                  context.l10n.rewardClaimStatusLabel,
                  rewardClaimStatusLabel(context.l10n, claim),
                  valueColor: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 13),
            _NoticeBox(
              text: rewardClaimTransferNote(context.l10n, claim),
              color: statusColor,
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

class _ReceiptBrandMark extends StatelessWidget {
  const _ReceiptBrandMark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 42),
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
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
  const _ReceiptRow(
    this.label,
    this.value, {
    this.highlighted = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool highlighted;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      color: valueColor ??
          (highlighted ? Theme.of(context).colorScheme.primary : null),
      fontWeight: FontWeight.w900,
      height: 1.35,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Text(value, style: valueStyle),
            ],
          );
        }

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
                style: valueStyle,
              ),
            ),
          ],
        );
      },
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
        borderRadius: BorderRadius.circular(8),
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

class _RewardClaimDetailState extends StatelessWidget {
  const _RewardClaimDetailState({required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 54, 14, 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: error
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

Color _statusColor(RewardClaimItem claim) {
  if (claim.isPaid) return const Color(0xFF28A81E);
  if (claim.isRejected) return const Color(0xFFED2C25);
  return const Color(0xFFE29300);
}
