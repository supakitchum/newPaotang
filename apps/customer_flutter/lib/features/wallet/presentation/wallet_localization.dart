import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../data/wallet_models.dart';

String walletLedgerTitle(
  CustomerLocalizations l10n,
  WalletLedgerEntry entry,
) {
  final reference = entry.referenceType.toLowerCase();
  final type = entry.entryType.toLowerCase();
  final reason = entry.reason.toLowerCase();

  if (reference.contains('topup')) return l10n.walletLedgerTopup;
  if (reference == 'order') return l10n.walletLedgerOrder;
  if (reference.contains('reward_claim')) return l10n.walletLedgerRewardClaim;
  if (reference.contains('activity_claim')) {
    return reason.contains('cashback') || reason.contains('refund')
        ? l10n.walletLedgerActivityCashback
        : l10n.walletLedgerActivityReward;
  }
  if (reference.contains('order_refund') ||
      reference.contains('order_cancel')) {
    return l10n.walletLedgerOrderRefund;
  }
  if (type == 'debit') return l10n.walletLedgerDebit;
  if (type == 'credit') return l10n.walletLedgerCredit;
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
