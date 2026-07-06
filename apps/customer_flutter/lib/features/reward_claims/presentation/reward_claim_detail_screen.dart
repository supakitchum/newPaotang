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
      showBottomNavigation: false,
      compactHeader: true,
      child: _RewardClaimDetailPageBody(
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
            onRetry: () => ref.invalidate(rewardClaimDetailProvider(claimId)),
          ),
        ),
      ),
    );
  }
}

class _RewardClaimDetailPageBody extends StatelessWidget {
  const _RewardClaimDetailPageBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: CustomerPageBody(
                  maxWidth: 640,
                  top: 12,
                  bottom: 24,
                  mobileHorizontal: 10,
                  wideHorizontal: 10,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RewardClaimReceipt extends ConsumerWidget {
  const _RewardClaimReceipt({required this.claim});

  final RewardClaimItem claim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(context, claim);
    final receiptMark = ref.watch(mobileBootstrapProvider).maybeWhen(
          data: (data) {
            final watermark = data.ticketImageWatermark.trim();
            if (watermark.isNotEmpty) return watermark;
            return data.lotteryProductLabel.trim();
          },
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
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.ticketLabelGovernmentLottery,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
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
                  valueFontSize: 13,
                ),
              ],
            ),
            const SizedBox(height: 13),
            _NoticeBox(
              text: rewardClaimTransferNote(context.l10n, claim),
              color: statusColor,
              backgroundColor: _noticeBackgroundColor(context, claim),
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
              _AdminNote(
                note: claim.adminNote,
                rejected: claim.status == RewardClaimStatus.rejected,
              ),
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
      constraints: const BoxConstraints(minWidth: 42, maxWidth: 76),
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Divider(height: 1, color: colorScheme.outlineVariant),
        const SizedBox(height: 12),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
    this.valueFontSize,
  });

  final String label;
  final String value;
  final bool highlighted;
  final Color? valueColor;
  final double? valueFontSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final valueLines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.35,
        );
    final valueStyle = TextStyle(
      color: valueColor ??
          (highlighted ? colorScheme.primary : colorScheme.onSurface),
      fontSize: valueFontSize ?? 17,
      fontWeight: FontWeight.w900,
      height: 1.35,
    );
    final valueWidget = _ReceiptValueLines(
      lines: valueLines.isEmpty ? const ['-'] : valueLines,
      style: valueStyle,
      alignEnd: true,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              const SizedBox(height: 4),
              _ReceiptValueLines(
                lines: valueLines.isEmpty ? const ['-'] : valueLines,
                style: valueStyle,
                alignEnd: false,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 118,
                maxWidth: constraints.maxWidth * 0.48,
              ),
              child: Text(label, style: labelStyle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: valueWidget,
            ),
          ],
        );
      },
    );
  }
}

class _ReceiptValueLines extends StatelessWidget {
  const _ReceiptValueLines({
    required this.lines,
    required this.style,
    required this.alignEnd,
  });

  final List<String> lines;
  final TextStyle style;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < lines.length; index++) ...[
          Text(
            lines[index],
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: style,
          ),
          if (index < lines.length - 1) const SizedBox(height: 3),
        ],
      ],
    );
  }
}

class _MoneySection extends StatelessWidget {
  const _MoneySection({required this.claim});

  final RewardClaimItem claim;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final taxAmount = (claim.prizeAmount * 0.005).round();
    final feeAmount = (claim.prizeAmount * 0.01).round();
    final l10n = context.l10n;

    return Column(
      children: [
        Divider(height: 1, color: colorScheme.outlineVariant),
        const SizedBox(height: 12),
        _MoneyRow(l10n.ticketLabelPrizeAmount, formatBaht(claim.prizeAmount)),
        _MoneyRow(
          l10n.rewardClaimTaxLabel,
          l10n.rewardClaimZeroBaht,
          discountOriginal: formatBaht(taxAmount),
          helper: l10n.rewardClaimWaived(formatBaht(taxAmount)),
          positive: true,
        ),
        _MoneyRow(
          l10n.rewardClaimFeeLabel,
          l10n.rewardClaimZeroBaht,
          discountOriginal: formatBaht(feeAmount),
          helper: l10n.rewardClaimWaived(formatBaht(feeAmount)),
          positive: true,
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: colorScheme.outlineVariant),
        const SizedBox(height: 10),
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
    this.discountOriginal = '',
    this.helper = '',
    this.positive = false,
    this.total = false,
  });

  final String label;
  final String value;
  final String discountOriginal;
  final String helper;
  final bool positive;
  final bool total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: total ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          fontSize: total ? 19 : 15,
          fontWeight: FontWeight.w500,
          height: 1.35,
        );
    final hasDiscount = helper.isNotEmpty || discountOriginal.isNotEmpty;
    final positiveColor =
        Color.lerp(colorScheme.tertiary, colorScheme.primary, 0.12) ??
            colorScheme.tertiary;
    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: positive ? positiveColor : colorScheme.onSurface,
          fontSize: total
              ? 19
              : hasDiscount && positive
                  ? 14
                  : 17,
          fontWeight: total ? FontWeight.w500 : FontWeight.w900,
          height: 1.35,
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final valueBlock = _MoneyValueBlock(
            value: value,
            valueStyle: valueStyle,
            discountOriginal: discountOriginal,
            helper: helper,
            alignEnd: !compact,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 4),
                valueBlock,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 118,
                  maxWidth: constraints.maxWidth * 0.48,
                ),
                child: Text(label, style: labelStyle),
              ),
              const SizedBox(width: 8),
              Expanded(child: valueBlock),
            ],
          );
        },
      ),
    );
  }
}

class _MoneyValueBlock extends StatelessWidget {
  const _MoneyValueBlock({
    required this.value,
    required this.valueStyle,
    required this.discountOriginal,
    required this.helper,
    required this.alignEnd,
  });

  final String value;
  final TextStyle? valueStyle;
  final String discountOriginal;
  final String helper;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDiscount = helper.isNotEmpty || discountOriginal.isNotEmpty;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (hasDiscount) ...[
          Wrap(
            alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              if (discountOriginal.isNotEmpty)
                Text(
                  discountOriginal,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.72,
                        ),
                        decoration: TextDecoration.lineThrough,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              if (helper.isNotEmpty)
                Text(
                  helper,
                  textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 3),
        ],
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: valueStyle,
        ),
      ],
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.text,
    required this.color,
    required this.backgroundColor,
  });

  final String text;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: backgroundColor,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.45,
            ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final color = rejected ? colorScheme.error : colorScheme.onSurfaceVariant;
    final backgroundColor = rejected
        ? Color.lerp(colorScheme.surface, colorScheme.error, 0.08) ??
            colorScheme.error.withValues(alpha: 0.08)
        : colorScheme.surfaceContainerHighest;
    final borderColor = rejected
        ? Color.lerp(colorScheme.outlineVariant, colorScheme.error, 0.34) ??
            colorScheme.error.withValues(alpha: 0.34)
        : colorScheme.outlineVariant;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
        color: backgroundColor,
      ),
      child: Text(
        note,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.45,
            ),
      ),
    );
  }
}

class _RewardClaimDetailState extends StatelessWidget {
  const _RewardClaimDetailState({
    required this.message,
    this.error = false,
    this.onRetry,
  });

  final String message;
  final bool error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 52),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: error
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                    fontSize: 18,
                    fontWeight: error ? FontWeight.w800 : FontWeight.w700,
                    height: 1.35,
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                style: _rewardClaimDetailOutlinePillStyle(context),
                onPressed: onRetry,
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

ButtonStyle _rewardClaimDetailOutlinePillStyle(BuildContext context) {
  return OutlinedButton.styleFrom(
    minimumSize: const Size(160, 44),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    shape: const StadiumBorder(),
    side: BorderSide(color: Theme.of(context).colorScheme.primary),
    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
        ),
  );
}

Color _statusColor(BuildContext context, RewardClaimItem claim) {
  final colorScheme = Theme.of(context).colorScheme;
  if (claim.isPaid) {
    return Color.lerp(colorScheme.tertiary, colorScheme.primary, 0.12) ??
        colorScheme.tertiary;
  }
  if (claim.isRejected) return colorScheme.error;
  return Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.32) ??
      colorScheme.primary;
}

Color _noticeBackgroundColor(BuildContext context, RewardClaimItem claim) {
  final colorScheme = Theme.of(context).colorScheme;
  final statusColor = _statusColor(context, claim);
  final alpha = claim.isRejected ? 0.10 : 0.13;
  return Color.lerp(colorScheme.surface, statusColor, alpha) ??
      statusColor.withValues(alpha: alpha);
}
