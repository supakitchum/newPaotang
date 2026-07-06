import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../data/wallet_models.dart';

String walletLedgerTitle(
  CustomerLocalizations l10n,
  WalletLedgerEntry entry,
) {
  final reference = _walletLedgerToken(entry.referenceType);
  final referenceCompact = _walletLedgerCompactToken(entry.referenceType);
  final type = _walletLedgerToken(entry.entryType);
  final reason = entry.reason.toLowerCase();

  if (reference.contains('topup')) return l10n.walletLedgerTopup;
  if (reference == 'order') return l10n.walletLedgerOrder;
  if (reference.contains('reward_claim') ||
      referenceCompact.contains('rewardclaim')) {
    return l10n.walletLedgerRewardClaim;
  }
  if (reference.contains('activity_claim') ||
      referenceCompact.contains('activityclaim')) {
    return reason.contains('cashback') ||
            reason.contains('refund') ||
            reason.contains('เงินคืน')
        ? l10n.walletLedgerActivityCashback
        : l10n.walletLedgerActivityReward;
  }
  if (reference.contains('order_refund') ||
      reference.contains('order_cancel') ||
      referenceCompact.contains('orderrefund') ||
      referenceCompact.contains('ordercancel')) {
    return l10n.walletLedgerOrderRefund;
  }
  if (type == 'debit' || type.contains('_debit')) {
    return l10n.walletLedgerDebit;
  }
  if (type == 'credit' || type.contains('_credit')) {
    return l10n.walletLedgerCredit;
  }
  return l10n.walletLedgerGeneric;
}

String walletLedgerSubtitle(
  CustomerLocalizations l10n,
  WalletLedgerEntry entry,
) {
  final reason = entry.reason.trim();
  if (reason.isNotEmpty) return reason;
  return entry.referenceId.isNotEmpty
      ? l10n.walletLedgerReference(entry.referenceId)
      : l10n.walletLedgerSuccess;
}

String walletLedgerDate(
  CustomerLocalizations l10n,
  WalletLedgerEntry entry,
) {
  return formatLocalizedDateTime(entry.createdAt, l10n.locale.toLanguageTag());
}

String _walletLedgerToken(String value) {
  return value
      .trim()
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}_${match.group(2)}',
      )
      .replaceAll(RegExp(r'[\s\-.]+'), '_')
      .toLowerCase();
}

String _walletLedgerCompactToken(String value) {
  return value.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '').toLowerCase();
}
