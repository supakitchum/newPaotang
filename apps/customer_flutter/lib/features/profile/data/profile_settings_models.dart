import '../../../core/utils/api_payload.dart';

class RewardBankAccount {
  const RewardBankAccount({
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
  });

  factory RewardBankAccount.fromJson(Map<String, dynamic> json) {
    final bank = asMap(json['bank']);
    return RewardBankAccount(
      bankName: _firstProfileText([
        json['bank_name'],
        json['bankName'],
        bank['name'],
        bank['display_name'],
        bank['displayName'],
        json['bank'],
      ]),
      accountName: _firstProfileText([
        json['account_name'],
        json['accountName'],
        json['bank_deposit_name'],
        json['bankDepositName'],
        json['bank_account_name'],
        json['bankAccountName'],
        json['holder_name'],
        json['holderName'],
      ]),
      accountNumber: _firstProfileText([
        json['account_number'],
        json['accountNumber'],
        json['account_no'],
        json['accountNo'],
        json['bank_account_no'],
        json['bankAccountNo'],
        json['bank_account_number'],
        json['bankAccountNumber'],
        json['bank_deposit_number'],
        json['bankDepositNumber'],
        json['number'],
        json['no'],
      ]).replaceAll(RegExp(r'\D'), ''),
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
    final payoutMethod = _firstProfileText([
      json['payout_method'],
      json['payoutMethod'],
      json['method'],
      json['reward_payout_method'],
      json['rewardPayoutMethod'],
      json['type'],
    ]);
    final type = _firstProfileText([
      json['type'],
      json['payout_type'],
      json['payoutType'],
      payoutMethod,
    ]);
    return AutoRewardSetting(
      enabled: _profileBool([
        json['enabled'],
        json['is_enabled'],
        json['isEnabled'],
        json['active'],
        json['is_active'],
        json['isActive'],
        json['auto_claim_enabled'],
        json['autoClaimEnabled'],
        json['status'],
      ]),
      payoutMethod: payoutMethod,
      type: type,
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
    this.walletId = '',
    this.walletName = '',
  });

  factory CustomerProfileSettings.fromJson(Map<String, dynamic> json) {
    final payload = _profilePayload(json);
    return CustomerProfileSettings(
      id: _firstProfileText([
        payload['id'],
        payload['customer_id'],
        payload['customerId'],
        payload['member_id'],
        payload['memberId'],
        payload['uuid'],
      ]),
      name: _firstProfileText([
        payload['name'],
        payload['full_name'],
        payload['fullName'],
        payload['display_name'],
        payload['displayName'],
        _joinedProfileName(payload),
      ]),
      customerNo: _firstProfileText([
        payload['member_no'],
        payload['memberNo'],
        payload['customer_no'],
        payload['customerNo'],
        payload['member_code'],
        payload['memberCode'],
        payload['customer_code'],
        payload['customerCode'],
        payload['code'],
        payload['id'],
      ]),
      phone: _firstProfileText([
        payload['phone'],
        payload['phone_number'],
        payload['phoneNumber'],
        payload['mobile'],
        payload['mobile_no'],
        payload['mobileNo'],
      ]),
      bankAccount: RewardBankAccount.fromJson(_profileBankAccount(payload)),
      autoReward: AutoRewardSetting.fromJson(_profileAutoReward(payload)),
      walletId: _profileWalletId(payload),
      walletName: _profileWalletName(payload),
    );
  }

  final String id;
  final String name;
  final String customerNo;
  final String phone;
  final RewardBankAccount bankAccount;
  final AutoRewardSetting autoReward;
  final String walletId;
  final String walletName;
}

Map<String, dynamic> _profilePayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 5) return json;

  for (final key in _profileWrapperKeys) {
    final profile = asMap(json[key]);
    if (profile.isEmpty) continue;
    final merged = Map<String, dynamic>.from(json)
      ..removeWhere((key, _) => _profileWrapperKeys.contains(key));
    merged.addAll(_profilePayload(profile, depth + 1));
    return merged;
  }
  return json;
}

const _profileWrapperKeys = [
  'profile',
  'customer_profile',
  'customerProfile',
  'profile_settings',
  'profileSettings',
  'customer',
  'member',
  'user',
  'account',
  'resource',
  'data',
  'result',
];

Map<String, dynamic> _profileBankAccount(Map<String, dynamic> json) {
  for (final key in const [
    'reward_payout_bank_account',
    'rewardPayoutBankAccount',
    'reward_bank_account',
    'rewardBankAccount',
    'payout_bank_account',
    'payoutBankAccount',
    'bank_account',
    'bankAccount',
    'bank',
  ]) {
    final bank = asMap(json[key]);
    if (bank.isNotEmpty) return bank;
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> _profileAutoReward(Map<String, dynamic> json) {
  for (final key in const [
    'auto_reward_claim',
    'autoRewardClaim',
    'auto_reward',
    'autoReward',
    'reward_auto_claim',
    'rewardAutoClaim',
    'auto_claim',
    'autoClaim',
  ]) {
    final setting = asMap(json[key]);
    if (setting.isNotEmpty) return setting;
  }
  return const <String, dynamic>{};
}

String _profileWalletId(Map<String, dynamic> json) {
  final wallet = asMap(json['wallet']);
  final primaryWallet = asMap(json['primary_wallet']);
  final primaryWalletCamel = asMap(json['primaryWallet']);
  final values = [
    json['wallet_id'],
    json['walletId'],
    json['primary_wallet_id'],
    json['primaryWalletId'],
    wallet['id'],
    wallet['wallet_id'],
    wallet['walletId'],
    primaryWallet['id'],
    primaryWallet['wallet_id'],
    primaryWallet['walletId'],
    primaryWalletCamel['id'],
    primaryWalletCamel['wallet_id'],
    primaryWalletCamel['walletId'],
  ];
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _profileWalletName(Map<String, dynamic> json) {
  final wallet = asMap(json['wallet']);
  final primaryWallet = asMap(json['primary_wallet']);
  final primaryWalletCamel = asMap(json['primaryWallet']);
  return _firstProfileText([
    wallet['name'],
    wallet['display_name'],
    wallet['displayName'],
    wallet['wallet_name'],
    wallet['walletName'],
    primaryWallet['name'],
    primaryWallet['display_name'],
    primaryWallet['displayName'],
    primaryWallet['wallet_name'],
    primaryWallet['walletName'],
    primaryWalletCamel['name'],
    primaryWalletCamel['display_name'],
    primaryWalletCamel['displayName'],
    primaryWalletCamel['wallet_name'],
    primaryWalletCamel['walletName'],
    json['wallet_name'],
    json['walletName'],
  ]);
}

String _joinedProfileName(Map<String, dynamic> json) {
  return [
    json['first_name'],
    json['firstName'],
    json['last_name'],
    json['lastName'],
  ].where((value) => value?.toString().trim().isNotEmpty == true).join(' ');
}

String _firstProfileText(Iterable<Object?> values) {
  for (final value in values) {
    if (value is Map || value is Iterable) continue;
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

bool _profileBool(Iterable<Object?> values) {
  for (final value in values) {
    if (value == null) continue;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) continue;
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'enabled' ||
        normalized == 'active' ||
        normalized == 'ready';
  }
  return false;
}

String maskWalletId(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '-';
  final suffix =
      digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
  return '006 XXXXXXXX $suffix';
}
