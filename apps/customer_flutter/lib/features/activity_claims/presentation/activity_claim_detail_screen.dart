import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../data/activity_claim_models.dart';
import '../data/activity_claim_repository.dart';
import '../../reward_claims/presentation/claim_realtime_monitor.dart';
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
      currentPath: '/profile',
      sensitive: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncStateView(
            value: claim,
            data: (item) => _ActivityClaimReceipt(claim: item),
            empty: const _ActivityClaimEmptyDetail(),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.redeem_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.activityClaimRewardTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                _StatusBadge(
                  label: localizedActivityClaimStatusLabel(context, claim),
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _NoticeBox(
              text: localizedActivityClaimTransferNote(context, claim),
              color: statusColor,
            ),
            const SizedBox(height: 16),
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
                ),
                _ReceiptRow(
                  l10n.activityClaimStatusLabel,
                  localizedActivityClaimStatusLabel(context, claim),
                ),
              ],
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
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

class _ActivityClaimEmptyDetail extends StatelessWidget {
  const _ActivityClaimEmptyDetail();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          context.l10n.activityClaimEmptyDetail,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

Color _statusColor(ActivityClaimItem claim) {
  if (claim.isPaid) return Colors.green.shade700;
  if (claim.isRejected) return Colors.red.shade700;
  return Colors.orange.shade800;
}
