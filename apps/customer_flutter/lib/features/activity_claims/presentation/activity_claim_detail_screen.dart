import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/activity_claim_models.dart';
import '../data/activity_claim_repository.dart';
import '../../reward_claims/presentation/claim_realtime_monitor.dart';
import 'activity_claim_error_message.dart';
import 'activity_claim_localization.dart';

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

    return AppShell(
      title: l10n.activityClaimDetailTitle,
      currentPath: '/activity-claims',
      backPath: '/activity-claims',
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
              data: (item) => _ActivityClaimReceipt(claim: item),
              loading: () => _ActivityClaimDetailState(
                message: l10n.activityClaimDetailLoading,
              ),
              error: (error, __) => _ActivityClaimDetailState(
                message: activityClaimErrorMessage(
                  error,
                  l10n.activityClaimDetailLoadFailed,
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

class _ActivityClaimReceipt extends StatelessWidget {
  const _ActivityClaimReceipt({required this.claim});

  final ActivityClaimItem claim;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(claim);
    final l10n = context.l10n;
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
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Icon(
                    Icons.redeem_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.activityClaimRewardTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF111827),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        localizedActivityClaimActivityName(context, claim),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF64748B),
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
                ),
              ],
            ),
            const SizedBox(height: 13),
            _NoticeBox(
              text: localizedActivityClaimTransferNote(context, claim),
              color: statusColor,
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
            if (claim.customerNote.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _PlainNote(
                title: l10n.activityClaimCustomerNoteTitle,
                note: claim.customerNote,
              ),
            ],
            if (claim.adminNote.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _PlainNote(
                title: l10n.activityClaimAdminNoteTitle,
                note: claim.adminNote,
                rejected: claim.isRejected,
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

  final ActivityClaimItem claim;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        const Divider(height: 1),
        const SizedBox(height: 10),
        _MoneyRow(l10n.activityClaimAmountLabel, formatBaht(claim.amount)),
        const Divider(height: 18),
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
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: total ? Theme.of(context).colorScheme.primary : null,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _PlainNote extends StatelessWidget {
  const _PlainNote({
    required this.title,
    required this.note,
    this.rejected = false,
  });

  final String title;
  final String note;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final color = rejected ? Colors.red.shade700 : Colors.grey.shade800;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: rejected ? Colors.red.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(note, style: TextStyle(color: color, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _ActivityClaimDetailState extends StatelessWidget {
  const _ActivityClaimDetailState({required this.message, this.error = false});

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

Color _statusColor(ActivityClaimItem claim) {
  if (claim.isPaid) return const Color(0xFF28A81E);
  if (claim.isRejected) return const Color(0xFFED2C25);
  return const Color(0xFFE29300);
}
