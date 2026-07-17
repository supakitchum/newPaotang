import '../../../core/utils/api_payload.dart';
import '../../../core/utils/formatters.dart';
import '../../profile/data/profile_settings_models.dart';

class AffiliateOverview {
  const AffiliateOverview({
    required this.isAffiliate,
    required this.affiliate,
    required this.links,
    required this.profile,
    required this.stats,
    required this.payoutPolicy,
    required this.commissions,
    required this.payouts,
  });

  factory AffiliateOverview.empty() {
    return const AffiliateOverview(
      isAffiliate: false,
      affiliate: null,
      links: [],
      profile: null,
      stats: AffiliateStats.empty(),
      payoutPolicy: AffiliatePayoutPolicy.empty(),
      commissions: [],
      payouts: [],
    );
  }

  factory AffiliateOverview.fromJson(Map<String, dynamic> json) {
    final payload = _affiliateOverviewPayload(json);
    final affiliate = _firstAffiliateMap([
      payload['affiliate'],
      payload['affiliate_account'],
      payload['affiliateAccount'],
      payload['account'],
    ]);
    final profile = _firstAffiliateMap([
      payload['profile'],
      payload['customer_profile'],
      payload['customerProfile'],
    ]);
    return AffiliateOverview(
      isAffiliate: _affiliateBool(
        payload['is_affiliate'] ??
            payload['isAffiliate'] ??
            payload['affiliate_enabled'] ??
            payload['affiliateEnabled'],
      ),
      affiliate:
          affiliate.isEmpty ? null : AffiliateAccount.fromJson(affiliate),
      links: _firstAffiliateMapList([
        payload['links'],
        payload['referral_links'],
        payload['referralLinks'],
        payload['affiliate_links'],
        payload['affiliateLinks'],
      ]).map(AffiliateLink.fromJson).toList(growable: false),
      profile: profile.isEmpty ? null : AffiliateProfile.fromJson(profile),
      stats: AffiliateStats.fromJson(
        _firstAffiliateMap([
          payload['stats'],
          payload['statistics'],
          payload['affiliate_stats'],
          payload['affiliateStats'],
        ]),
      ),
      payoutPolicy: AffiliatePayoutPolicy.fromJson(
        _firstAffiliateMap([
          payload['payout_policy'],
          payload['payoutPolicy'],
          payload['withdrawal_policy'],
          payload['withdrawalPolicy'],
          payload['policy'],
        ]),
      ),
      commissions: _firstAffiliateMapList([
        payload['commissions'],
        payload['commission_items'],
        payload['commissionItems'],
      ]).map(AffiliateCommission.fromJson).toList(growable: false),
      payouts: _firstAffiliateMapList([
        payload['payouts'],
        payload['payout_items'],
        payload['payoutItems'],
        payload['withdrawals'],
      ]).map(AffiliatePayout.fromJson).toList(growable: false),
    );
  }

  final bool isAffiliate;
  final AffiliateAccount? affiliate;
  final List<AffiliateLink> links;
  final AffiliateProfile? profile;
  final AffiliateStats stats;
  final AffiliatePayoutPolicy payoutPolicy;
  final List<AffiliateCommission> commissions;
  final List<AffiliatePayout> payouts;

  AffiliateLink? get primaryLink => links.isEmpty ? null : links.first;

  String get referralCode {
    final linkCode = primaryLink?.code ?? '';
    if (linkCode.isNotEmpty) return linkCode;
    return affiliate?.code ?? '';
  }

  String get referralUrl {
    final link = primaryLink;
    if (link != null && link.canonicalUrl.isNotEmpty) {
      return link.canonicalUrl;
    }
    if (affiliate?.canonicalUrl.isNotEmpty ?? false) {
      return affiliate!.canonicalUrl;
    }
    if (affiliate?.referralUrl.isNotEmpty ?? false) {
      return affiliate!.referralUrl;
    }
    if (referralCode.isEmpty) return '';
    return '/?ref=$referralCode';
  }

  String get storeName {
    final value = affiliate?.displayName ?? '';
    return value.trim();
  }

  RewardBankAccount get bankAccount {
    final profileBank = profile?.bankAccount;
    if (profileBank != null && profileBank.isComplete) return profileBank;
    final affiliateBank = affiliate?.bankAccount;
    if (affiliateBank != null && affiliateBank.isComplete) return affiliateBank;
    return const RewardBankAccount(
      bankName: '',
      accountName: '',
      accountNumber: '',
    );
  }
}

class AffiliateAccount {
  const AffiliateAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.referralUrl,
    required this.canonicalUrl,
    required this.walletBalance,
    required this.bankAccount,
  });

  factory AffiliateAccount.fromJson(Map<String, dynamic> json) {
    final payload = _affiliateEntityPayload(
      json,
      const ['affiliate', 'affiliate_account', 'affiliateAccount', 'account'],
    );
    final payoutProfile = _firstAffiliateMap([
      payload['payout_profile'],
      payload['payoutProfile'],
      payload['reward_payout_profile'],
      payload['rewardPayoutProfile'],
    ]);
    return AffiliateAccount(
      id: _firstAffiliateText([
        payload['id'],
        payload['affiliate_id'],
        payload['affiliateId'],
      ]),
      code: _firstAffiliateText([
        payload['code'],
        payload['referral_code'],
        payload['referralCode'],
        payload['affiliate_code'],
        payload['affiliateCode'],
      ]),
      name: _firstAffiliateText([
        payload['name'],
        payload['store_name'],
        payload['storeName'],
        payload['display_name'],
        payload['displayName'],
        payload['customer_name'],
        payload['customerName'],
      ]),
      status: _firstAffiliateText([
        payload['status'],
        payload['affiliate_status'],
        payload['affiliateStatus'],
      ]),
      referralUrl: _firstAffiliateText([
        payload['referral_url'],
        payload['referralUrl'],
        payload['share_url'],
        payload['shareUrl'],
      ]),
      canonicalUrl: _firstAffiliateText([
        payload['canonical_url'],
        payload['canonicalUrl'],
      ]),
      walletBalance: moneyToDisplayNumber(
        payload['wallet_balance'] ?? payload['walletBalance'],
      ),
      bankAccount: RewardBankAccount.fromJson(
        _firstAffiliateMap([
          payoutProfile['bank_account'],
          payoutProfile['bankAccount'],
          payload['bank_account'],
          payload['bankAccount'],
        ]),
      ),
    );
  }

  final String id;
  final String code;
  final String name;
  final String status;
  final String referralUrl;
  final String canonicalUrl;
  final double walletBalance;
  final RewardBankAccount bankAccount;

  String get displayName => name.trim();
}

class AffiliateLink {
  const AffiliateLink({
    required this.id,
    required this.code,
    required this.canonicalUrl,
    required this.status,
  });

  factory AffiliateLink.fromJson(Map<String, dynamic> json) {
    final payload = _affiliateEntityPayload(
      json,
      const ['link', 'referral_link', 'referralLink', 'affiliateLink'],
    );
    return AffiliateLink(
      id: _firstAffiliateText(
        [payload['id'], payload['link_id'], payload['linkId']],
      ),
      code: _firstAffiliateText([
        payload['code'],
        payload['referral_code'],
        payload['referralCode'],
      ]),
      canonicalUrl: _firstAffiliateText([
        payload['canonical_url'],
        payload['canonicalUrl'],
        payload['url'],
        payload['href'],
        payload['legacy_url'],
        payload['legacyUrl'],
      ]),
      status: _firstAffiliateText([payload['status'], payload['linkStatus']]),
    );
  }

  final String id;
  final String code;
  final String canonicalUrl;
  final String status;
}

class AffiliateProfile {
  const AffiliateProfile({
    required this.name,
    required this.bankAccount,
  });

  factory AffiliateProfile.fromJson(Map<String, dynamic> json) {
    final payload = _affiliateEntityPayload(
      json,
      const ['profile', 'customer_profile', 'customerProfile'],
    );
    return AffiliateProfile(
      name: _firstAffiliateText([
        payload['name'],
        payload['display_name'],
        payload['displayName'],
      ]),
      bankAccount: RewardBankAccount.fromJson(
        _firstAffiliateMap([
          payload['reward_payout_bank_account'],
          payload['rewardPayoutBankAccount'],
          payload['bank_account'],
          payload['bankAccount'],
        ]),
      ),
    );
  }

  final String name;
  final RewardBankAccount bankAccount;
}

class AffiliateStats {
  const AffiliateStats({
    required this.totalCommission,
    required this.approvedCommission,
    required this.pendingCommission,
    required this.requestedPayout,
    required this.availableBalance,
    required this.convertedCount,
    required this.visitorCount,
    required this.registeredCount,
  });

  const AffiliateStats.empty()
      : totalCommission = 0,
        approvedCommission = 0,
        pendingCommission = 0,
        requestedPayout = 0,
        availableBalance = 0,
        convertedCount = 0,
        visitorCount = 0,
        registeredCount = 0;

  factory AffiliateStats.fromJson(Map<String, dynamic> json) {
    final payload = _affiliateEntityPayload(
      json,
      const ['stats', 'statistics', 'affiliate_stats', 'affiliateStats'],
    );
    return AffiliateStats(
      totalCommission: moneyToDisplayNumber(
        payload['total_commission'] ?? payload['totalCommission'],
      ),
      approvedCommission: moneyToDisplayNumber(
        payload['approved_commission'] ?? payload['approvedCommission'],
      ),
      pendingCommission: moneyToDisplayNumber(
        payload['pending_commission'] ?? payload['pendingCommission'],
      ),
      requestedPayout: moneyToDisplayNumber(
        payload['requested_payout'] ?? payload['requestedPayout'],
      ),
      availableBalance: moneyToDisplayNumber(
        payload['available_balance'] ?? payload['availableBalance'],
      ),
      convertedCount: _affiliateInt(
        payload['converted_count'] ?? payload['convertedCount'],
      ),
      visitorCount: _affiliateInt(
        payload['visitor_count'] ?? payload['visitorCount'],
      ),
      registeredCount: _affiliateInt(
        payload['registered_count'] ?? payload['registeredCount'],
      ),
    );
  }

  final double totalCommission;
  final double approvedCommission;
  final double pendingCommission;
  final double requestedPayout;
  final double availableBalance;
  final int convertedCount;
  final int visitorCount;
  final int registeredCount;
}

class AffiliatePayoutPolicy {
  const AffiliatePayoutPolicy({
    required this.minimumPayout,
    required this.programName,
  });

  const AffiliatePayoutPolicy.empty()
      : minimumPayout = 300,
        programName = '';

  factory AffiliatePayoutPolicy.fromJson(Map<String, dynamic> json) {
    final payload = _affiliateEntityPayload(
      json,
      const [
        'payout_policy',
        'payoutPolicy',
        'withdrawal_policy',
        'withdrawalPolicy',
        'policy',
      ],
    );
    return AffiliatePayoutPolicy(
      minimumPayout: moneyToDisplayNumber(
        payload['minimum_payout_amount'] ??
            payload['minimumPayoutAmount'] ??
            payload['minimum_payout'] ??
            payload['minimumPayout'],
        fallback: 300,
      ),
      programName: _firstAffiliateText([
        payload['program_name'],
        payload['programName'],
      ]),
    );
  }

  final double minimumPayout;
  final String programName;
}

class AffiliateCommission {
  const AffiliateCommission({
    required this.id,
    required this.orderId,
    required this.status,
    required this.amount,
    required this.calculatedAt,
    required this.createdAt,
  });

  factory AffiliateCommission.fromJson(Map<String, dynamic> json) {
    final payload = _affiliateEntityPayload(
      json,
      const ['commission', 'affiliate_commission', 'affiliateCommission'],
    );
    return AffiliateCommission(
      id: _firstAffiliateText([
        payload['id'],
        payload['commission_id'],
        payload['commissionId'],
      ]),
      orderId: _firstAffiliateText([
        payload['order_id'],
        payload['orderId'],
        asMap(payload['order'])['id'],
        asMap(payload['order'])['reference'],
      ]),
      status: _firstAffiliateText([
        payload['status'],
        payload['commission_status'],
        payload['commissionStatus'],
      ]),
      amount: moneyToDisplayNumber(
        payload['amount'] ??
            payload['commission_amount'] ??
            payload['commissionAmount'],
      ),
      calculatedAt: payload['calculated_at'] ?? payload['calculatedAt'],
      createdAt: payload['created_at'] ?? payload['createdAt'],
    );
  }

  final String id;
  final String orderId;
  final String status;
  final double amount;
  final Object? calculatedAt;
  final Object? createdAt;
}

class AffiliatePayout {
  const AffiliatePayout({
    required this.id,
    required this.status,
    required this.payoutMethod,
    required this.amount,
    required this.createdAt,
  });

  factory AffiliatePayout.fromJson(Map<String, dynamic> json) {
    final payload = _affiliateEntityPayload(
      json,
      const ['payout', 'withdrawal', 'affiliate_payout', 'affiliatePayout'],
    );
    return AffiliatePayout(
      id: _firstAffiliateText([
        payload['id'],
        payload['payout_id'],
        payload['payoutId'],
        payload['withdrawal_id'],
        payload['withdrawalId'],
      ]),
      status: _firstAffiliateText([
        payload['status'],
        payload['payout_status'],
        payload['payoutStatus'],
      ]),
      payoutMethod: _firstAffiliateText([
        payload['payout_method'],
        payload['payoutMethod'],
        payload['method'],
        asMap(payload['channel'])['code'],
        asMap(payload['channel'])['value'],
      ]),
      amount: moneyToDisplayNumber(
        payload['amount'] ??
            payload['payout_amount'] ??
            payload['payoutAmount'] ??
            payload['withdrawal_amount'] ??
            payload['withdrawalAmount'],
      ),
      createdAt: payload['created_at'] ?? payload['createdAt'],
    );
  }

  final String id;
  final String status;
  final String payoutMethod;
  final double amount;
  final Object? createdAt;
}

class AffiliatePage<T> {
  const AffiliatePage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory AffiliatePage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFactory,
  ) {
    final payload = _affiliatePagePayload(json);
    final meta = _firstAffiliateMap([
      payload['meta'],
      payload['pagination'],
      json['meta'],
      json['pagination'],
    ]);
    final nextCursor = _firstAffiliateText([
      meta['next_cursor'],
      meta['nextCursor'],
      meta['cursor'],
      payload['next_cursor'],
      payload['nextCursor'],
    ]);
    return AffiliatePage<T>(
      items:
          _affiliatePageRows(payload).map(itemFactory).toList(growable: false),
      nextCursor: nextCursor,
      hasMore: _affiliateBool(meta['has_more'] ?? meta['hasMore']) &&
          nextCursor.isNotEmpty,
    );
  }

  final List<T> items;
  final String nextCursor;
  final bool hasMore;
}

Map<String, dynamic> _affiliateOverviewPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (json.isEmpty || depth >= 5) return json;
  const signals = {
    'is_affiliate',
    'isAffiliate',
    'affiliate',
    'affiliateAccount',
    'links',
    'referralLinks',
    'stats',
    'affiliateStats',
    'payout_policy',
    'payoutPolicy',
  };
  if (signals.any(json.containsKey)) return json;

  for (final key in const [
    'data',
    'result',
    'resource',
    'payload',
    'affiliate_overview',
    'affiliateOverview',
    'overview',
  ]) {
    final nested = asMap(json[key]);
    if (nested.isEmpty) continue;
    final resolved = _affiliateOverviewPayload(nested, depth + 1);
    if (signals.any(resolved.containsKey)) {
      return <String, dynamic>{...json, ...resolved};
    }
  }
  return json;
}

Map<String, dynamic> _affiliateEntityPayload(
  Map<String, dynamic> json,
  List<String> entityKeys, [
  int depth = 0,
]) {
  if (json.isEmpty || depth >= 4) return json;
  for (final key in entityKeys) {
    final nested = asMap(json[key]);
    if (nested.isNotEmpty) {
      return _affiliateEntityPayload(nested, entityKeys, depth + 1);
    }
  }
  for (final key in const ['data', 'result', 'resource', 'payload']) {
    final nested = asMap(json[key]);
    if (nested.isNotEmpty) {
      return _affiliateEntityPayload(nested, entityKeys, depth + 1);
    }
  }
  return json;
}

Map<String, dynamic> _affiliatePagePayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (json.isEmpty || depth >= 5) return json;
  const rowKeys = {
    'data',
    'items',
    'rows',
    'results',
    'commissions',
    'commissionItems',
    'payouts',
    'payoutItems',
    'withdrawals',
  };
  if (rowKeys.any((key) => json[key] is List)) return json;

  for (final key in const [
    'data',
    'result',
    'resource',
    'payload',
    'page',
    'commissionPage',
    'payoutPage',
  ]) {
    final nested = asMap(json[key]);
    if (nested.isEmpty) continue;
    final resolved = _affiliatePagePayload(nested, depth + 1);
    if (rowKeys.any((candidate) => resolved[candidate] is List)) {
      return <String, dynamic>{
        ...json,
        ...resolved,
        if (!resolved.containsKey('meta') && json.containsKey('meta'))
          'meta': json['meta'],
      };
    }
  }
  return json;
}

List<Map<String, dynamic>> _affiliatePageRows(Map<String, dynamic> payload) {
  for (final key in const [
    'data',
    'items',
    'rows',
    'results',
    'commissions',
    'commission_items',
    'commissionItems',
    'payouts',
    'payout_items',
    'payoutItems',
    'withdrawals',
  ]) {
    final value = payload[key];
    if (value is List) return asMapList(value);
    final nested = asMap(value);
    if (nested.isNotEmpty) {
      final rows = _affiliatePageRows(nested);
      if (rows.isNotEmpty) return rows;
    }
  }
  return const [];
}

Map<String, dynamic> _firstAffiliateMap(Iterable<Object?> values) {
  for (final value in values) {
    final map = asMap(value);
    if (map.isNotEmpty) return map;
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _firstAffiliateMapList(Iterable<Object?> values) {
  for (final value in values) {
    if (value is List) return asMapList(value);
    final nested = asMap(value);
    if (nested.isNotEmpty) {
      final rows = _affiliatePageRows(nested);
      if (rows.isNotEmpty) return rows;
    }
  }
  return const [];
}

String _firstAffiliateText(Iterable<Object?> values) {
  for (final value in values) {
    final text = _affiliateScalarText(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _affiliateScalarText(Object? value, [int depth = 0]) {
  if (value == null || depth >= 4) return '';
  if (value is String) return value.trim();
  if (value is num || value is bool) return value.toString();
  final map = asMap(value);
  if (map.isEmpty) return '';
  for (final key in const [
    'value',
    'code',
    'key',
    'id',
    'text',
    'label',
    'name',
    'rawValue',
  ]) {
    final text = _affiliateScalarText(map[key], depth + 1);
    if (text.isNotEmpty) return text;
  }
  return '';
}

bool _affiliateBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = _affiliateScalarText(value).toLowerCase();
  return const {
    '1',
    'true',
    'yes',
    'on',
    'active',
    'enabled',
    'available',
    'allowed',
  }.contains(text);
}

int _affiliateInt(Object? value) {
  final text = _affiliateScalarText(value).replaceAll(',', '');
  return int.tryParse(text) ?? double.tryParse(text)?.round() ?? 0;
}
