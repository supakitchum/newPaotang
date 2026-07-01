import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../data/ticket_models.dart';

String ticketStatusLabel(CustomerLocalizations l10n, CustomerTicket ticket) {
  final status = ticket.rewardStatus.status;
  if (status == 'winning') return l10n.ticketStatusWinning;
  if (status == 'non_winning') return l10n.ticketStatusNonWinning;
  if (status == 'rejected') return l10n.ticketStatusClaimFailed;
  if (status == 'paid' || status == 'paid_out') return l10n.ticketStatusPaid;
  if (status == 'submitted' || status == 'under_review') {
    return l10n.ticketStatusPendingClaim;
  }

  final visibleStatus = ticket.status;
  if (visibleStatus == 'claimed' || visibleStatus == 'paid') {
    return l10n.ticketStatusPaid;
  }
  return l10n.ticketStatusPendingResult;
}

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
