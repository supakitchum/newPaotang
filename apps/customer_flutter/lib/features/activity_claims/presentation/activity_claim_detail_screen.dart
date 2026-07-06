import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/activity_claim_models.dart';
import '../data/activity_claim_repository.dart';
import '../../reward_claims/presentation/claim_realtime_monitor.dart';
import 'activity_claim_error_message.dart';
import 'activity_claim_localization.dart';

Color _activityClaimDetailPrimaryTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.primary, colorScheme.surface, 0.88) ??
    colorScheme.primary.withValues(alpha: 0.12);

class ActivityClaimDetailScreen extends ConsumerWidget {
  const ActivityClaimDetailScreen({required this.claimId, super.key});

  final String claimId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(
      activityClaimRealtimeTickProvider,
      (_, __) => ref.invalidate(activityClaimDetailProvider(claimId)),
    );
    final claim = ref.watch(activityClaimDetailProvider(claimId));
    final l10n = context.l10n;
    final reviewerName = ref.watch(mobileBootstrapProvider).maybeWhen(
          data: (data) => data.siteName.trim(),
          orElse: () => '',
        );

    return AppShell(
      title: l10n.activityClaimDetailTitle,
      currentPath: '/activity-claims',
      backPath: '/activity-claims',
      sensitive: true,
      showBottomNavigation: false,
      compactHeader: true,
      child: _ActivityClaimDetailPageBody(
        child: claim.when(
          data: (item) => _ActivityClaimReceipt(
            claim: item,
            reviewerName: reviewerName,
          ),
          loading: () => _ActivityClaimDetailState(
            message: l10n.activityClaimDetailLoading,
          ),
          error: (error, __) => _ActivityClaimDetailState(
            message: activityClaimErrorMessage(
              error,
              l10n.activityClaimDetailLoadFailed,
            ),
            error: true,
            onRetry: () => ref.invalidate(activityClaimDetailProvider(claimId)),
          ),
        ),
      ),
    );
  }
}

class _ActivityClaimDetailPageBody extends StatelessWidget {
  const _ActivityClaimDetailPageBody({required this.child});

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

class _ActivityClaimReceipt extends StatelessWidget {
  const _ActivityClaimReceipt({
    required this.claim,
    required this.reviewerName,
  });

  final ActivityClaimItem claim;
  final String reviewerName;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context, claim);
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _activityClaimDetailPrimaryTint(colorScheme),
                    ),
                  ),
                  child: Icon(
                    Icons.card_giftcard_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.activityClaimRewardTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        localizedActivityClaimActivityName(context, claim),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            _ReceiptSection(
              rows: [
                _ReceiptRow(
                  l10n.activityClaimRecipientLabel,
                  localizedActivityClaimCustomerName(context, claim),
                  highlighted: true,
                ),
                _ReceiptRow(
                  l10n.activityClaimPayoutChannelLabel,
                  localizedActivityClaimPayoutChannel(context, claim),
                  highlighted: true,
                ),
                _ReceiptRow(
                  l10n.activityClaimPayoutMethodLabel,
                  localizedActivityClaimPayoutMethod(context, claim),
                  highlighted: true,
                ),
                _ReceiptRow(
                  l10n.activityClaimStatusLabel,
                  localizedActivityClaimStatusLabel(context, claim),
                  valueColor: statusColor,
                  valueFontSize: 13,
                ),
              ],
            ),
            const SizedBox(height: 13),
            _NoticeBox(
              text: localizedActivityClaimTransferNote(
                context,
                claim,
                reviewerName: reviewerName,
              ),
              color: statusColor,
              backgroundColor: _noticeBackgroundColor(context, claim),
            ),
            const SizedBox(height: 14),
            _ReceiptSection(
              rows: [
                _ReceiptRow(
                  l10n.activityClaimActivityLabel,
                  localizedActivityClaimActivityName(context, claim),
                ),
                _ReceiptRow(
                  l10n.activityClaimRewardTypeLabel,
                  localizedActivityClaimRewardLabel(context, claim),
                ),
                _ReceiptRow(
                  l10n.activityClaimReferenceLabel,
                  claim.displayReference,
                ),
                _ReceiptRow(
                  l10n.activityClaimSubmittedAtLabel,
                  localizedActivityClaimSubmittedAt(context, claim),
                ),
                if (claim.reviewedAt != null || claim.paidAt != null)
                  _ReceiptRow(
                    claim.paidAt != null
                        ? l10n.activityClaimPaidAtLabel
                        : l10n.activityClaimReviewedAtLabel,
                    localizedActivityClaimReviewedOrPaidAt(context, claim),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _MoneySection(claim: claim),
            if (claim.adminNote.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _AdminNote(
                note: claim.adminNote,
                rejected: claim.status == ActivityClaimStatus.rejected,
              ),
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

  final ActivityClaimItem claim;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Column(
      children: [
        Divider(height: 1, color: colorScheme.outlineVariant),
        const SizedBox(height: 12),
        _MoneyRow(l10n.activityClaimAmountLabel, formatBaht(claim.amount)),
        const SizedBox(height: 8),
        Divider(height: 1, color: colorScheme.outlineVariant),
        const SizedBox(height: 10),
        _MoneyRow(
          l10n.activityClaimNetAmountLabel,
          formatBaht(claim.amount),
          total: true,
        ),
      ],
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow(this.label, this.value, {this.total = false});

  final String label;
  final String value;
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
    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
          fontSize: total ? 19 : 17,
          fontWeight: total ? FontWeight.w500 : FontWeight.w900,
          height: 1.35,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              const SizedBox(height: 4),
              Text(value, style: valueStyle),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      ),
    );
  }
}

class _AdminNote extends StatelessWidget {
  const _AdminNote({
    required this.note,
    this.rejected = false,
  });

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          note,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
        ),
      ),
    );
  }
}

class _ActivityClaimDetailState extends StatelessWidget {
  const _ActivityClaimDetailState({
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
                style: _activityClaimDetailOutlinePillStyle(context),
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

ButtonStyle _activityClaimDetailOutlinePillStyle(BuildContext context) {
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

Color _statusColor(BuildContext context, ActivityClaimItem claim) {
  final colorScheme = Theme.of(context).colorScheme;
  if (claim.isPaid) {
    return Color.lerp(colorScheme.tertiary, colorScheme.primary, 0.12) ??
        colorScheme.tertiary;
  }
  if (claim.isRejected) return colorScheme.error;
  return Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.32) ??
      colorScheme.primary;
}

Color _noticeBackgroundColor(BuildContext context, ActivityClaimItem claim) {
  final colorScheme = Theme.of(context).colorScheme;
  final statusColor = _statusColor(context, claim);
  final alpha = claim.isRejected ? 0.10 : 0.13;
  return Color.lerp(colorScheme.surface, statusColor, alpha) ??
      statusColor.withValues(alpha: alpha);
}
