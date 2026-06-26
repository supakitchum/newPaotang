import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/idempotency_key.dart';
import 'affiliate_models.dart';

final affiliateRepositoryProvider = Provider<AffiliateRepository>((ref) {
  return AffiliateRepository(ref.watch(apiClientProvider));
});

final affiliateOverviewProvider =
    FutureProvider.autoDispose<AffiliateOverview>((ref) async {
  return ref.watch(affiliateRepositoryProvider).overview();
});

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

  Future<AffiliatePayout> createPayout({
    required double amount,
    required String payoutMethod,
    Map<String, dynamic>? bankAccount,
  }) async {
    final response = await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/affiliate/payouts',
      headers: {'Idempotency-Key': newIdempotencyKey('affiliate_payout')},
      data: {
        'amount': {
          'amount': (amount * 100).round(),
          'currency': 'THB',
        },
        'payout_method': payoutMethod,
        if (bankAccount != null) 'bank_account': bankAccount,
      },
    );
    return AffiliatePayout.fromJson(unwrapPayload(response.data));
  }
}
