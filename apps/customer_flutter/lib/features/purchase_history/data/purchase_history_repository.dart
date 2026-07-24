import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/provider_cache.dart';
import 'purchase_history_models.dart';

final purchaseHistoryRepositoryProvider = Provider<PurchaseHistoryRepository>((
  ref,
) {
  return PurchaseHistoryRepository(ref.watch(apiClientProvider));
});

final purchaseHistoryDetailProvider = FutureProvider.autoDispose
    .family<PurchaseHistoryOrder, String>((ref, id) async {
      ref.keepForCustomerNavigation();
      return ref.watch(purchaseHistoryRepositoryProvider).detail(id);
    });

class PurchaseHistoryRepository {
  const PurchaseHistoryRepository(this._api);

  final ApiClient _api;

  Future<PurchaseHistoryPage> list({int page = 1, int perPage = 20}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/orders',
      query: {'page': page, 'per_page': perPage},
    );
    return PurchaseHistoryPage.fromJson(asMap(response.data));
  }

  Future<PurchaseHistoryOrder> detail(String id) async {
    final encodedId = Uri.encodeComponent(id.trim());
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/orders/$encodedId',
    );
    return PurchaseHistoryOrder.fromJson(unwrapPayload(response.data));
  }
}
