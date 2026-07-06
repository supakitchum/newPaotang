import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import 'reward_claim_models.dart';

final rewardClaimRepositoryProvider = Provider<RewardClaimRepository>((ref) {
  return RewardClaimRepository(ref.watch(apiClientProvider));
});

final rewardClaimDetailProvider =
    FutureProvider.autoDispose.family<RewardClaimItem, String>((ref, id) async {
  return ref.watch(rewardClaimRepositoryProvider).detail(id);
});

class RewardClaimRepository {
  const RewardClaimRepository(this._api);

  final ApiClient _api;

  Future<RewardClaimPage> list({int limit = 20, String? cursor}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/reward-claims',
      query: {
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return RewardClaimPage.fromJson(asMap(response.data));
  }

  Future<RewardClaimItem> detail(String id) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/reward-claims/$id',
    );
    return RewardClaimItem.fromJson(asMap(response.data));
  }
}
