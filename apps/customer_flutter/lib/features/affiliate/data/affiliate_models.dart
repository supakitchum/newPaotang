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
    return AffiliateOverview(
      isAffiliate: json['is_affiliate'] == true,
      affiliate: asMap(json['affiliate']).isEmpty
          ? null
          : AffiliateAccount.fromJson(asMap(json['affiliate'])),
      links: asMapList(json['links'])
          .map(AffiliateLink.fromJson)
          .toList(growable: false),
      profile: asMap(json['profile']).isEmpty
          ? null
          : AffiliateProfile.fromJson(asMap(json['profile'])),
      stats: AffiliateStats.fromJson(asMap(json['stats'])),
      payoutPolicy: AffiliatePayoutPolicy.fromJson(
        asMap(json['payout_policy']),
      ),
      commissions: asMapList(json['commissions'])
          .map(AffiliateCommission.fromJson)
          .toList(growable: false),
      payouts: asMapList(json['payouts'])
          .map(AffiliatePayout.fromJson)
          .toList(growable: false),
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
    final payoutProfile = asMap(json['payout_profile']);
    return AffiliateAccount(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: (json['name'] ??
              json['store_name'] ??
              json['display_name'] ??
              json['customer_name'] ??
              '')
          .toString(),
      status: json['status']?.toString() ?? '',
      referralUrl: json['referral_url']?.toString() ?? '',
      canonicalUrl: json['canonical_url']?.toString() ?? '',
      walletBalance: moneyToDisplayNumber(json['wallet_balance']),
      bankAccount: RewardBankAccount.fromJson(
        asMap(payoutProfile['bank_account']),
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
    return AffiliateLink(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      canonicalUrl:
          (json['canonical_url'] ?? json['url'] ?? json['legacy_url'] ?? '')
              .toString(),
      status: json['status']?.toString() ?? '',
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
    return AffiliateProfile(
      name: json['name']?.toString() ?? '',
      bankAccount: RewardBankAccount.fromJson(
        asMap(json['reward_payout_bank_account'] ?? json['bank_account']),
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
    return AffiliateStats(
      totalCommission: moneyToDisplayNumber(json['total_commission']),
      approvedCommission: moneyToDisplayNumber(json['approved_commission']),
      pendingCommission: moneyToDisplayNumber(json['pending_commission']),
      requestedPayout: moneyToDisplayNumber(json['requested_payout']),
      availableBalance: moneyToDisplayNumber(json['available_balance']),
      convertedCount:
          int.tryParse((json['converted_count'] ?? 0).toString()) ?? 0,
      visitorCount: int.tryParse((json['visitor_count'] ?? 0).toString()) ?? 0,
      registeredCount:
          int.tryParse((json['registered_count'] ?? 0).toString()) ?? 0,
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
    return AffiliatePayoutPolicy(
      minimumPayout: moneyToDisplayNumber(
        json['minimum_payout_amount'] ?? json['minimum_payout'],
        fallback: 300,
      ),
      programName: json['program_name']?.toString() ?? '',
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
    return AffiliateCommission(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      amount: moneyToDisplayNumber(json['amount']),
      calculatedAt: json['calculated_at'],
      createdAt: json['created_at'],
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
    return AffiliatePayout(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      payoutMethod: json['payout_method']?.toString() ?? '',
      amount: moneyToDisplayNumber(json['amount']),
      createdAt: json['created_at'],
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
    final meta = asMap(json['meta']);
    return AffiliatePage<T>(
      items: asMapList(json['data']).map(itemFactory).toList(growable: false),
      nextCursor: meta['next_cursor']?.toString() ?? '',
      hasMore: meta['has_more'] == true,
    );
  }

  final List<T> items;
  final String nextCursor;
  final bool hasMore;
}
