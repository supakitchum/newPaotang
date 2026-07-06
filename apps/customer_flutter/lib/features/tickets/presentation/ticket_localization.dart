import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../data/ticket_models.dart';

String ticketStatusLabel(CustomerLocalizations l10n, CustomerTicket ticket) {
  final status = ticket.rewardStatus.status;
  final claimStatus = ticket.rewardStatus.claimStatus;
  if (status == 'winning') return l10n.ticketStatusWinning;
  if (status == 'non_winning') return l10n.ticketStatusNonWinning;
  if (_ticketRejectedStatuses.contains(status) ||
      _ticketRejectedStatuses.contains(claimStatus)) {
    return l10n.ticketStatusClaimFailed;
  }
  if (_ticketCancelledStatuses.contains(status) ||
      _ticketCancelledStatuses.contains(claimStatus)) {
    return l10n.ticketStatusClaimCancelled;
  }
  if (_ticketPaidStatuses.contains(status) ||
      _ticketPaidStatuses.contains(claimStatus)) {
    return l10n.ticketStatusPaid;
  }
  if (_ticketApprovedStatuses.contains(status) ||
      _ticketApprovedStatuses.contains(claimStatus)) {
    return l10n.ticketStatusApproved;
  }
  if (_ticketSubmittedStatuses.contains(status) ||
      _ticketSubmittedStatuses.contains(claimStatus)) {
    return l10n.ticketStatusPendingClaim;
  }

  final visibleStatus = ticket.status;
  if (visibleStatus == 'claimed' || visibleStatus == 'paid') {
    return l10n.ticketStatusPaid;
  }
  return l10n.ticketStatusPendingResult;
}

const _ticketSubmittedStatuses = {
  'submitted',
  'claim_submitted',
  'under_review',
  'pending',
};

const _ticketApprovedStatuses = {
  'approved',
  'claim_approved',
};

const _ticketPaidStatuses = {
  'paid',
  'paid_out',
  'claim_paid',
};

const _ticketRejectedStatuses = {
  'rejected',
  'claim_rejected',
};

const _ticketCancelledStatuses = {
  'cancelled',
  'canceled',
  'claim_cancelled',
  'claim_canceled',
};

String ticketPrizeTypeLabel(CustomerLocalizations l10n, String type) {
  return l10n.ticketPrizeType(type);
}

List<String> ticketPrizeNames(
  CustomerLocalizations l10n,
  CustomerTicket ticket,
) {
  final names = ticket.prizes
      .map((prize) => ticketPrizeTypeLabel(l10n, prize.prizeType))
      .where((name) => name.trim().isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (names.isNotEmpty) return names;
  if (ticket.rewardStatus.prizeType.isNotEmpty) {
    return [ticketPrizeTypeLabel(l10n, ticket.rewardStatus.prizeType)];
  }
  return [l10n.ticketPrizeFallback];
}

String ticketPrizeSummary(CustomerLocalizations l10n, CustomerTicket ticket) {
  final names = ticketPrizeNames(l10n, ticket);
  if (ticket.prizes.length > 1) {
    return l10n.ticketPrizeMore(names.first, ticket.prizes.length - 1);
  }
  if (ticket.prizes.length == 1 || ticket.rewardStatus.prizeType.isNotEmpty) {
    return names.first;
  }
  return ticket.prizeAmount > 0
      ? l10n.ticketPrizeFallback
      : ticketStatusLabel(l10n, ticket);
}

String ticketDrawDateText(CustomerLocalizations l10n, CustomerTicket ticket) {
  return formatLotteryDrawDateText(
    name: ticket.gameName,
    drawAt: ticket.drawAt,
    localeTag: l10n.locale.toLanguageTag(),
  );
}

String rewardClaimSubmittedText(
  CustomerLocalizations l10n,
  RewardClaimSubmission submission,
) {
  return formatLocalizedDateTime(
    submission.createdAt,
    l10n.locale.toLanguageTag(),
  );
}
