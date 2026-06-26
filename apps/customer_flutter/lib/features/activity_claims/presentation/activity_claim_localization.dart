import 'package:flutter/widgets.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../data/activity_claim_models.dart';

String localizedActivityClaimActivityName(
  BuildContext context,
  ActivityClaimItem claim,
) {
  final value = claim.activityName.trim();
  return value.isEmpty ? context.l10n.activityClaimActivityFallback : value;
}

String localizedActivityClaimCustomerName(
  BuildContext context,
  ActivityClaimItem claim,
) {
  final value = claim.customerName.trim();
  return value.isEmpty ? context.l10n.activityClaimCustomerFallback : value;
}

String localizedActivityClaimRewardLabel(
  BuildContext context,
  ActivityClaimItem claim,
) {
  return localizedActivityRewardType(
    context,
    claim.type == 'cashback' ? 'cashback' : claim.predictionType,
  );
}

String localizedActivityRewardType(BuildContext context, String type) {
  final l10n = context.l10n;
  return switch (type) {
    'cashback' => l10n.activityClaimRewardCashback,
    'first_prize_last2' => l10n.activityClaimRewardFirstPrizeLast2,
    'first_prize_last3' => l10n.activityClaimRewardFirstPrizeLast3,
    'last2' => l10n.activityClaimRewardLast2,
    _ => l10n.activityClaimRewardFallback,
  };
}

String localizedActivityClaimStatusLabel(
  BuildContext context,
  ActivityClaimItem claim,
) {
  final l10n = context.l10n;
  if (claim.isPaid) return l10n.activityClaimStatusPaid;
  return switch (claim.status) {
    ActivityClaimStatus.rejected => l10n.activityClaimStatusRejected,
    ActivityClaimStatus.cancelled => l10n.activityClaimStatusCancelled,
    ActivityClaimStatus.approved => l10n.activityClaimStatusApproved,
    ActivityClaimStatus.submitted => l10n.activityClaimStatusSubmitted,
    ActivityClaimStatus.paid => l10n.activityClaimStatusPaid,
    ActivityClaimStatus.unknown => l10n.activityClaimStatusSubmitted,
  };
}

String localizedActivityClaimTransferNote(
  BuildContext context,
  ActivityClaimItem claim,
) {
  final l10n = context.l10n;
  if (claim.isPaid) return l10n.activityClaimNotePaid;
  return switch (claim.status) {
    ActivityClaimStatus.rejected => l10n.activityClaimNoteRejected,
    ActivityClaimStatus.cancelled => l10n.activityClaimNoteCancelled,
    ActivityClaimStatus.approved => l10n.activityClaimNoteApproved,
    ActivityClaimStatus.submitted => l10n.activityClaimNoteSubmitted,
    ActivityClaimStatus.paid => l10n.activityClaimNotePaid,
    ActivityClaimStatus.unknown => l10n.activityClaimNoteSubmitted,
  };
}

String localizedActivityClaimPayoutMethod(
  BuildContext context,
  ActivityClaimItem claim,
) {
  return claim.payoutMethod == ActivityClaimPayoutMethod.bankTransfer.apiValue
      ? context.l10n.activityClaimBankTransfer
      : context.l10n.activityClaimWalletCredit;
}

String localizedActivityClaimPayoutSummary(
  BuildContext context,
  ActivityClaimItem claim,
) {
  if (claim.payoutMethod == ActivityClaimPayoutMethod.bankTransfer.apiValue) {
    final bank = claim.bankName.trim().isEmpty
        ? context.l10n.activityClaimBankFallback
        : claim.bankName.trim();
    return context.l10n.activityClaimBankSummary(bank);
  }
  return context.l10n.activityClaimWalletSummary(claim.walletName);
}

String localizedActivityClaimPayoutChannel(
  BuildContext context,
  ActivityClaimItem claim,
) {
  if (claim.payoutMethod == ActivityClaimPayoutMethod.bankTransfer.apiValue) {
    final bank = claim.bankName.trim().isEmpty
        ? context.l10n.activityClaimBankFallback
        : claim.bankName.trim();
    return '$bank\n${maskActivityBankAccount(claim.bankAccountNumber)}';
  }
  return claim.walletName;
}

String localizedActivityClaimSubmittedAt(
  BuildContext context,
  ActivityClaimItem claim,
) {
  return formatLocalizedDateTime(
    claim.submittedAt ?? claim.createdAt,
    context.l10n.locale.toLanguageTag(),
  );
}

String localizedActivityClaimReviewedOrPaidAt(
  BuildContext context,
  ActivityClaimItem claim,
) {
  return formatLocalizedDateTime(
    claim.paidAt ?? claim.reviewedAt,
    context.l10n.locale.toLanguageTag(),
  );
}
