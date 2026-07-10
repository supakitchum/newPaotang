import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../data/reward_claim_models.dart';

String formatRewardClaimBaht(CustomerLocalizations l10n, num value) {
  final formatted = l10n.formatBaht(value);
  final unit = l10n.commonBahtSuffix.trim();
  final amount = unit.isEmpty
      ? formatted.trim()
      : formatted
          .replaceFirst(RegExp('\\s*${RegExp.escape(unit)}\$'), '')
          .trim();
  final numericValue = value.toDouble();
  final cleanAmount = numericValue.isFinite &&
          (numericValue - numericValue.roundToDouble()).abs() <= 0.000001
      ? amount.replaceFirst(RegExp(r'[\.,]00$'), '')
      : amount;
  return unit.isEmpty ? cleanAmount : '$cleanAmount $unit';
}

String rewardClaimCustomerName(
  CustomerLocalizations l10n,
  RewardClaimItem claim,
) {
  final name = claim.customerName.trim();
  return name.isEmpty ? l10n.rewardClaimCustomerFallback : name;
}

String rewardClaimStatusLabel(
  CustomerLocalizations l10n,
  RewardClaimItem claim,
) {
  if (claim.isPaid) return l10n.rewardClaimStatusPaid;
  return switch (claim.status) {
    RewardClaimStatus.rejected => l10n.rewardClaimStatusRejected,
    RewardClaimStatus.cancelled => l10n.rewardClaimStatusCancelled,
    RewardClaimStatus.approved => l10n.rewardClaimStatusApproved,
    RewardClaimStatus.submitted => l10n.rewardClaimStatusSubmitted,
    RewardClaimStatus.paid => l10n.rewardClaimStatusPaid,
    RewardClaimStatus.unknown => l10n.rewardClaimStatusSubmitted,
  };
}

String rewardClaimTransferNote(
  CustomerLocalizations l10n,
  RewardClaimItem claim,
) {
  if (claim.isPaid) return l10n.rewardClaimNotePaid;
  if (claim.status == RewardClaimStatus.rejected) {
    return l10n.rewardClaimNoteRejected;
  }
  if (claim.status == RewardClaimStatus.cancelled) {
    return l10n.rewardClaimNoteCancelled;
  }
  if (claim.status == RewardClaimStatus.approved) {
    return l10n.rewardClaimNoteApproved;
  }
  return l10n.rewardClaimNoteSubmitted;
}

String rewardClaimPayoutSummary(
  CustomerLocalizations l10n,
  RewardClaimItem claim,
) {
  if (claim.payoutMethod == 'bank_transfer') {
    final name = _normalizedBankName(l10n, claim.bankName);
    return l10n.rewardClaimPayoutBank(
      name.isEmpty ? l10n.rewardClaimBankFallback : name,
    );
  }
  return l10n.rewardClaimPayoutWallet(_rewardClaimWalletName(l10n, claim));
}

String rewardClaimPayoutChannelText(
  CustomerLocalizations l10n,
  RewardClaimItem claim,
) {
  if (claim.payoutMethod == 'bank_transfer') {
    final bank = claim.bankName.trim().isEmpty
        ? l10n.rewardClaimBankFallback
        : claim.bankName.trim();
    return '$bank\n${maskBankAccount(claim.bankAccountNumber)}';
  }
  return _rewardClaimWalletName(l10n, claim);
}

List<String> rewardClaimPrizeNames(
  CustomerLocalizations l10n,
  RewardClaimItem claim,
) {
  final names = claim.prizes
      .map((prize) => l10n.rewardClaimPrizeType(prize.prizeType))
      .where((name) => name.trim().isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (names.isNotEmpty) return names;
  return [l10n.rewardClaimPrizeType(claim.prizeType)];
}

String rewardClaimPrimaryPrizeSummary(
  CustomerLocalizations l10n,
  RewardClaimItem claim,
) {
  final names = rewardClaimPrizeNames(l10n, claim);
  if (claim.prizes.length > 1) {
    return l10n.rewardClaimPrizeMore(names.first, claim.prizes.length - 1);
  }
  return names.first;
}

String rewardClaimPrizeLines(
  CustomerLocalizations l10n,
  RewardClaimItem claim,
) {
  if (claim.prizes.isEmpty) {
    return '${l10n.rewardClaimPrizeType(claim.prizeType)}\n'
        '${formatRewardClaimBaht(l10n, claim.prizeAmount)}';
  }

  return claim.prizes
      .map(
        (prize) => '${l10n.rewardClaimPrizeType(prize.prizeType)}\n'
            '${formatRewardClaimBaht(l10n, prize.amount)}',
      )
      .join('\n\n');
}

String rewardClaimSubmittedText(
  CustomerLocalizations l10n,
  RewardClaimItem claim,
) {
  return formatLocalizedDateTime(
    claim.submittedAt ?? claim.createdAt,
    l10n.locale.toLanguageTag(),
  );
}

String rewardClaimDrawDateText(
  CustomerLocalizations l10n,
  RewardClaimTicket? ticket,
) {
  return formatLotteryDrawDateText(
    name: ticket?.gameName,
    drawAt: ticket?.drawAt,
    localeTag: l10n.locale.toLanguageTag(),
  );
}

String _normalizedBankName(CustomerLocalizations l10n, String value) {
  final prefix = l10n.rewardClaimBankPrefix;
  if (prefix.isEmpty) return value.trim();
  return value.replaceFirst(RegExp('^${RegExp.escape(prefix)}'), '').trim();
}

String _rewardClaimWalletName(
  CustomerLocalizations l10n,
  RewardClaimItem claim,
) {
  final name = claim.walletName.trim();
  return name.isEmpty ? l10n.rewardClaimWalletFallback : name;
}
