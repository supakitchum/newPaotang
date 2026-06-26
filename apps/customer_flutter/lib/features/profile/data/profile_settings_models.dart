import '../../../core/utils/api_payload.dart';

class RewardBankAccount {
  const RewardBankAccount({
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
  });

  factory RewardBankAccount.fromJson(Map<String, dynamic> json) {
    return RewardBankAccount(
      bankName: (json['bank_name'] ?? json['bank'] ?? '').toString(),
      accountName:
          (json['account_name'] ?? json['bank_deposit_name'] ?? '').toString(),
      accountNumber: (json['account_number'] ??
              json['account_no'] ??
              json['bank_account_no'] ??
              json['bank_deposit_number'] ??
              '')
          .toString()
          .replaceAll(RegExp(r'\D'), ''),
    );
  }

  final String bankName;
  final String accountName;
  final String accountNumber;

  bool get isComplete =>
      bankName.trim().isNotEmpty &&
      accountName.trim().isNotEmpty &&
      accountNumber.trim().isNotEmpty;

  String get maskedNumber {
    if (accountNumber.isEmpty) return '-';
    if (accountNumber.length <= 4) return accountNumber;
    final hidden = List.filled(accountNumber.length - 4, '*').join();
    return '$hidden${accountNumber.substring(accountNumber.length - 4)}';
  }

  Map<String, dynamic> toJson() {
    return {
      'bank_name': bankName.trim(),
      'account_name': accountName.trim(),
      'account_number': accountNumber.replaceAll(RegExp(r'\D'), ''),
    };
  }
}

class AutoRewardSetting {
  const AutoRewardSetting({
    required this.enabled,
    required this.payoutMethod,
    required this.type,
  });

  factory AutoRewardSetting.fromJson(Map<String, dynamic> json) {
    return AutoRewardSetting(
      enabled: json['enabled'] == true,
      payoutMethod: json['payout_method']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }

  final bool enabled;
  final String payoutMethod;
  final String type;

  bool get isBankTransfer =>
      payoutMethod == 'bank_transfer' || type == 'bank_transfer';
}

class CustomerProfileSettings {
  const CustomerProfileSettings({
    required this.id,
    required this.name,
    required this.customerNo,
    required this.phone,
    required this.bankAccount,
    required this.autoReward,
  });

  factory CustomerProfileSettings.fromJson(Map<String, dynamic> json) {
    return CustomerProfileSettings(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      customerNo: (json['member_no'] ?? json['customer_no'] ?? json['id'] ?? '')
          .toString(),
      phone: json['phone']?.toString() ?? '',
      bankAccount:
          RewardBankAccount.fromJson(asMap(json['reward_payout_bank_account'])),
      autoReward: AutoRewardSetting.fromJson(asMap(json['auto_reward_claim'])),
    );
  }

  final String id;
  final String name;
  final String customerNo;
  final String phone;
  final RewardBankAccount bankAccount;
  final AutoRewardSetting autoReward;
}

String maskWalletId(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final suffix =
      digits.length >= 4 ? digits.substring(digits.length - 4) : '1244';
  return '006 XXXXXXXX $suffix';
}
