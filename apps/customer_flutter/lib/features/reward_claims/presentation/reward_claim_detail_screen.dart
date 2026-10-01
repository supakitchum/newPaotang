import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/tenant_brand_header.dart';
import '../data/reward_claim_models.dart';
import '../data/reward_claim_repository.dart';
import 'claim_realtime_monitor.dart';
import 'reward_claim_error_message.dart';
import 'reward_claim_localization.dart';

const _rewardClaimDetailSurface = Color(0xFFFFFFFF);
const _rewardClaimDetailText = Color(0xFF111827);
const _rewardClaimDetailMuted = Color(0xFF64748B);
const _rewardClaimDetailSubtle = Color(0xFF94A3B8);
const _rewardClaimDetailDivider = Color(0xFFEEF2F7);
const _rewardClaimDetailLogoBorder = Color(0xFFDBEAFE);
const _rewardClaimDetailSuccess = Color(0xFF28A81E);
const _rewardClaimDetailSuccessBackground = Color(0xFFEFFCE8);
const _rewardClaimDetailPending = Color(0xFFE29300);
const _rewardClaimDetailPendingText = Color(0xFFB36A00);
const _rewardClaimDetailPendingBackground = Color(0xFFFFF7DC);
const _rewardClaimDetailRejected = Color(0xFFED2C25);
const _rewardClaimDetailRejectedBackground = Color(0xFFFFE1DF);
const _rewardClaimDetailPositive = Color(0xFF16A34A);
const _rewardClaimAdminNoteBackground = Color(0xFFF8FAFC);
const _rewardClaimAdminNoteBorder = Color(0xFFE2E8F0);
const _rewardClaimAdminNoteText = Color(0xFF475569);
const _rewardClaimAdminNoteRejectedBackground = Color(0xFFFFF1F2);
const _rewardClaimAdminNoteRejectedBorder = Color(0xFFFECdd3);
const _rewardClaimAdminNoteRejectedText = Color(0xFFB91C1C);
const _rewardClaimOutlineDisabledBorder = Color(0xFFCBD4DF);
const _rewardClaimOutlineDisabledText = Color(0xFF8A8F98);
const _rewardClaimOutlineDisabledBackground = Color(0xFFF2F4F7);

class RewardClaimDetailScreen extends ConsumerWidget {
  const RewardClaimDetailScreen({required this.claimId, super.key});

  final String claimId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(
      rewardClaimRealtimeTickProvider,
      (_, __) => ref.invalidate(rewardClaimDetailProvider(claimId)),
    );
    listenForCustomerOperationalError<RewardClaimItem>(
      ref: ref,
      context: context,
      provider: rewardClaimDetailProvider(claimId),
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
      heroContent: const SizedBox.shrink(),
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      child: _RewardClaimDetailPageBody(
        child: claim.when(
          data: (item) => _RewardClaimReceipt(claim: item),
          loading: () =>
              _RewardClaimDetailState(message: l10n.rewardClaimDetailLoading),
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
                color: _rewardClaimDetailSurface,
                child: CustomerPageBody(
                  maxWidth: 620,
                  top: 12,
                  bottom: 24,
                  mobileHorizontal: 10,
                  wideHorizontal: 10,
                  minViewportHeight: true,
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
    final statusColor = _statusColor(claim);
    final receiptMark = ref
        .watch(mobileBootstrapProvider)
        .maybeWhen(
          data: (data) {
            final productLabel = data.lotteryProductLabel.trim();
            if (productLabel.isNotEmpty) return productLabel;
            final watermark = data.ticketImageWatermark.trim();
            if (watermark.isNotEmpty) return watermark;
            final siteName = data.siteName.trim();
            if (siteName.isNotEmpty) return siteName;
            return context.l10n.contentRewardTermsOfficeAbbr.trim();
          },
          orElse: () => context.l10n.contentRewardTermsOfficeAbbr.trim(),
        );
    return ColoredBox(
      color: _rewardClaimDetailSurface,
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
                      color: _rewardClaimDetailText,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
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
              color: _noticeTextColor(claim),
              backgroundColor: _noticeBackgroundColor(claim),
            ),
            const SizedBox(height: 13),
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
            const SizedBox(height: 13),
            _MoneySection(claim: claim),
            if (claim.adminNote.trim().isNotEmpty) ...[
              const SizedBox(height: 13),
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
    final logoBorder = colorScheme.primary == AppTheme.appBlue
        ? _rewardClaimDetailLogoBorder
        : Color.lerp(colorScheme.primary, colorScheme.surface, 0.84) ??
              colorScheme.primaryContainer;
    return SizedBox.square(
      dimension: 42,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _rewardClaimDetailSurface,
          shape: BoxShape.circle,
          border: Border.all(color: logoBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.primaryOutlineBorder(colorScheme.primary),
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
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
        const Divider(height: 1, color: _rewardClaimDetailDivider),
        const SizedBox(height: 12),
        for (var index = 0; index < rows.length; index++) ...[
          rows[index],
          if (index < rows.length - 1) const SizedBox(height: 8),
        ],
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
    final primary = Theme.of(context).colorScheme.primary;
    final valueLines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: _rewardClaimDetailMuted,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.35,
    );
    final valueStyle = TextStyle(
      color:
          valueColor ??
          (highlighted
              ? AppTheme.detailKicker(primary)
              : _rewardClaimDetailText),
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
            Expanded(child: valueWidget),
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
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
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
    final taxAmount = (claim.prizeAmount * 0.005).round();
    final feeAmount = (claim.prizeAmount * 0.01).round();
    final l10n = context.l10n;

    return Column(
      children: [
        const Divider(height: 1, color: _rewardClaimDetailDivider),
        const SizedBox(height: 12),
        _MoneyRow(
          l10n.ticketLabelPrizeAmount,
          formatRewardClaimBaht(l10n, claim.prizeAmount),
        ),
        const SizedBox(height: 8),
        _MoneyRow(
          l10n.rewardClaimTaxLabel,
          l10n.rewardClaimZeroBaht,
          discountOriginal: formatRewardClaimBaht(l10n, taxAmount),
          helper: l10n.rewardClaimWaived(
            formatRewardClaimBaht(l10n, taxAmount),
          ),
          positive: true,
        ),
        const SizedBox(height: 8),
        _MoneyRow(
          l10n.rewardClaimFeeLabel,
          l10n.rewardClaimZeroBaht,
          discountOriginal: formatRewardClaimBaht(l10n, feeAmount),
          helper: l10n.rewardClaimWaived(
            formatRewardClaimBaht(l10n, feeAmount),
          ),
          positive: true,
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: _rewardClaimDetailDivider),
        const SizedBox(height: 10),
        _MoneyRow(
          l10n.ticketLabelNetAmount,
          formatRewardClaimBaht(l10n, claim.prizeAmount),
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
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: total ? _rewardClaimDetailText : _rewardClaimDetailMuted,
      fontSize: total ? 19 : 15,
      fontWeight: FontWeight.w500,
      height: 1.35,
    );
    final hasDiscount = helper.isNotEmpty || discountOriginal.isNotEmpty;
    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: positive ? _rewardClaimDetailPositive : _rewardClaimDetailText,
      fontSize: total
          ? 19
          : hasDiscount && positive
          ? 14
          : 17,
      fontWeight: total ? FontWeight.w500 : FontWeight.w900,
      height: 1.35,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final valueBlock = _MoneyValueBlock(
          value: value,
          valueStyle: valueStyle,
          discountOriginal: discountOriginal,
          helper: helper,
          alignEnd: true,
        );

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
    final hasDiscount = helper.isNotEmpty || discountOriginal.isNotEmpty;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
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
                    color: _rewardClaimDetailSubtle,
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (helper.isNotEmpty)
                Text(
                  helper,
                  textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _rewardClaimDetailMuted,
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
    final color = rejected
        ? _rewardClaimAdminNoteRejectedText
        : _rewardClaimAdminNoteText;
    final backgroundColor = rejected
        ? _rewardClaimAdminNoteRejectedBackground
        : _rewardClaimAdminNoteBackground;
    final borderColor = rejected
        ? _rewardClaimAdminNoteRejectedBorder
        : _rewardClaimAdminNoteBorder;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                color: error ? colorScheme.error : colorScheme.onSurfaceVariant,
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
  final primary = Theme.of(context).colorScheme.primary;
  return OutlinedButton.styleFrom(
    backgroundColor: Colors.white,
    disabledBackgroundColor: _rewardClaimOutlineDisabledBackground,
    disabledForegroundColor: _rewardClaimOutlineDisabledText,
    foregroundColor: AppTheme.primaryOutlineText(primary),
    minimumSize: const Size(160, 40),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    shape: const StadiumBorder(),
    textStyle: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  ).copyWith(
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled)
            ? _rewardClaimOutlineDisabledBorder
            : AppTheme.primaryOutlineBorder(primary),
      ),
    ),
  );
}

Color _statusColor(RewardClaimItem claim) {
  if (claim.isPaid) return _rewardClaimDetailSuccess;
  if (claim.isRejected) return _rewardClaimDetailRejected;
  return _rewardClaimDetailPending;
}

Color _noticeBackgroundColor(RewardClaimItem claim) {
  if (claim.isPaid) return _rewardClaimDetailSuccessBackground;
  if (claim.isRejected) return _rewardClaimDetailRejectedBackground;
  return _rewardClaimDetailPendingBackground;
}

Color _noticeTextColor(RewardClaimItem claim) {
  if (claim.isPaid) return _rewardClaimDetailSuccess;
  if (claim.isRejected) return _rewardClaimDetailRejected;
  return _rewardClaimDetailPendingText;
}
