import '../../../core/utils/formatters.dart';

class CustomerWallet {
  const CustomerWallet({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
  });

  factory CustomerWallet.fromJson(Map<String, dynamic> json) {
    return CustomerWallet(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'G Wallet',
      type: json['type']?.toString() ?? '',
      balance: moneyToDisplayNumber(json['balance']),
    );
  }

  final String id;
  final String name;
  final String type;
  final double balance;
}

class WalletLedgerEntry {
  const WalletLedgerEntry({
    required this.id,
    required this.entryType,
    required this.referenceType,
    required this.referenceId,
    required this.reason,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory WalletLedgerEntry.fromJson(Map<String, dynamic> json) {
    return WalletLedgerEntry(
      id: json['id']?.toString() ?? '',
      entryType: json['entry_type']?.toString() ?? '',
      referenceType: json['reference_type']?.toString() ?? '',
      referenceId: json['reference_id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      amount: moneyToDisplayNumber(json['amount']),
      balanceAfter: moneyToDisplayNumber(json['balance_after']),
      createdAt: json['created_at'] ?? json['posted_at'],
    );
  }

  final String id;
  final String entryType;
  final String referenceType;
  final String referenceId;
  final String reason;
  final double amount;
  final double balanceAfter;
  final Object? createdAt;

  bool get isCredit => amount > 0;
  bool get isDebit => amount < 0;
}

class WalletSummary {
  const WalletSummary({
    required this.wallets,
    required this.ledger,
    this.ledgerLoadFailed = false,
  });

  final List<CustomerWallet> wallets;
  final List<WalletLedgerEntry> ledger;
  final bool ledgerLoadFailed;

  CustomerWallet? get primaryWallet {
    for (final wallet in wallets) {
      if (wallet.type == '1' || wallet.type == 'primary') return wallet;
    }
    return wallets.isEmpty ? null : wallets.first;
  }

  double get balance => primaryWallet?.balance ?? 0;
}
