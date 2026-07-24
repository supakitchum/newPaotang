import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../../core/utils/provider_cache.dart';
import 'affiliate_models.dart';

final affiliateRepositoryProvider = Provider<AffiliateRepository>((ref) {
  return AffiliateRepository(ref.watch(apiClientProvider));
});

final affiliateOverviewProvider = FutureProvider.autoDispose<AffiliateOverview>(
  (ref) async {
    ref.keepForCustomerNavigation();
    return ref.watch(affiliateRepositoryProvider).overview();
  },
);

class AffiliateRepository {
  const AffiliateRepository(this._api);

  final ApiClient _api;

  Future<AffiliateOverview> overview() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/affiliate',
    );
    return AffiliateOverview.fromJson(asMap(response.data));
  }

  Future<AffiliateOverview> register({required String name}) async {
    final response = await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/affiliate',
      headers: {'Idempotency-Key': newIdempotencyKey('affiliate_register')},
      data: {'name': name},
    );
    return AffiliateOverview.fromJson(asMap(response.data));
  }

  Future<void> requestStoreName({required String name}) async {
    await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/affiliate/store-name-requests',
      headers: {'Idempotency-Key': newIdempotencyKey('affiliate_store_name')},
      data: {'name': name},
    );
  }

  Future<List<AffiliateTierCampaign>> campaigns() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/affiliate/tier-campaigns',
    );
    return asMapList(
      asMap(response.data)['data'],
    ).map(AffiliateTierCampaign.fromJson).toList(growable: false);
  }

  Future<AffiliatePayout> createPayout({
    required double amount,
    required String payoutMethod,
    String pin = '',
    String pinAssertionToken = '',
    Map<String, dynamic>? bankAccount,
  }) async {
    final response = await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/affiliate/payouts',
      headers: {'Idempotency-Key': newIdempotencyKey('affiliate_payout')},
      data: {
        'amount': {'amount': (amount * 100).round(), 'currency': 'THB'},
        'payout_method': payoutMethod,
        if (pinAssertionToken.isNotEmpty)
          'pin_assertion_token': pinAssertionToken
        else if (pin.isNotEmpty)
          'pin': pin,
        if (bankAccount != null) 'bank_account': bankAccount,
      },
    );
    return AffiliatePayout.fromJson(unwrapPayload(response.data));
  }

  Future<AffiliatePage<AffiliateCommission>> commissions({
    String cursor = '',
    int limit = 10,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/affiliate/commissions',
      query: {
        'limit': limit,
        if (cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      },
    );
    return AffiliatePage.fromJson(
      asMap(response.data),
      AffiliateCommission.fromJson,
    );
  }

  Future<AffiliatePage<AffiliatePayout>> payouts({
    String cursor = '',
    int limit = 10,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/affiliate/payouts',
      query: {
        'limit': limit,
        if (cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      },
    );
    return AffiliatePage.fromJson(
      asMap(response.data),
      AffiliatePayout.fromJson,
    );
  }
}
