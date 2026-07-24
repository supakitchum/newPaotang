import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../../core/utils/provider_cache.dart';
import '../../profile/data/profile_settings_models.dart';
import 'activity_claim_models.dart';

final activityClaimRepositoryProvider = Provider<ActivityClaimRepository>((
  ref,
) {
  return ActivityClaimRepository(ref.watch(apiClientProvider));
});

final activityClaimDetailProvider = FutureProvider.autoDispose
    .family<ActivityClaimItem, String>((ref, id) async {
      ref.keepForCustomerNavigation();
      return ref.watch(activityClaimRepositoryProvider).detail(id);
    });

class ActivityClaimRepository {
  const ActivityClaimRepository(this._api);

  final ApiClient _api;

  Future<ActivityClaimPage> list({int limit = 20, String? cursor}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/activity-claims',
      query: {
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return ActivityClaimPage.fromJson(asMap(response.data));
  }

  Future<ActivityClaimItem> detail(String id) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/activity-claims/$id',
    );
    return ActivityClaimItem.fromJson(asMap(response.data));
  }

  Future<ActivityClaimItem> create({
    required String awardId,
    required ActivityClaimPayoutMethod payoutMethod,
    String? pin,
    String? pinAssertionToken,
    RewardBankAccount? bankAccount,
    String note = '',
  }) async {
    final response = await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/activity-claims',
      headers: {
        'Idempotency-Key': newIdempotencyKey('customer_activity_claim'),
      },
      data: {
        'award_id': awardId,
        'payout_method': payoutMethod.apiValue,
        if (pinAssertionToken != null && pinAssertionToken.isNotEmpty)
          'pin_assertion_token': pinAssertionToken
        else if (pin != null && pin.isNotEmpty)
          'pin': pin,
        if (payoutMethod == ActivityClaimPayoutMethod.bankTransfer &&
            bankAccount != null &&
            bankAccount.isComplete)
          'bank_account': bankAccount.toJson(),
        if (note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return ActivityClaimItem.fromJson(asMap(response.data));
  }
}
