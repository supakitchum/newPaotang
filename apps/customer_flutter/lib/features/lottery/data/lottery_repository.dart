import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../results/data/result_repository.dart';
import 'lottery_models.dart';

final lotteryRepositoryProvider = Provider<LotteryRepository>((ref) {
  return LotteryRepository(ref.watch(apiClientProvider));
});

final currentGameIdProvider = FutureProvider.autoDispose<String>((ref) async {
  final game = await ref.watch(resultRepositoryProvider).currentGame();
  return game?.id ?? '';
});

class LotteryRepository {
  const LotteryRepository(this._api);

  final ApiClient _api;

  Future<LotteryStockPage> search({
    required String gameId,
    List<String> digits = const [],
    String number = '',
    String storeId = '',
    String cursor = '',
    int limit = 20,
  }) async {
    if (gameId.trim().isEmpty) {
      return const LotteryStockPage(
        items: [],
        nextCursor: '',
        hasMore: false,
        gameId: '',
        sellerName: '',
      );
    }

    final normalizedNumber = _normalizeSearchNumber(number);
    final normalizedDigits = _normalizeDigits(digits);
    final query = <String, dynamic>{
      'game_id': gameId,
      'mode': 'random',
      'limit': limit,
      if (normalizedNumber.isNotEmpty) 'number': normalizedNumber,
      if (normalizedNumber.isEmpty)
        for (var index = 0; index < normalizedDigits.length; index++)
          if (normalizedDigits[index].isNotEmpty)
            'd${index + 1}': normalizedDigits[index],
      if (storeId.trim().isNotEmpty) 'store_id': storeId.trim(),
      if (cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
    };

    final response = await _api.get<Map<String, dynamic>>(
      '/public/stock/search',
      auth: false,
      query: query,
    );
    return LotteryStockPage.fromJson(response.data);
  }

  Future<LotteryReservation> reserve({
    required String gameId,
    required LotteryStockItem item,
  }) async {
    final response = await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/reservations',
      data: {
        'game_id': gameId,
        'local_stock_item_ids': [item.localStockItemId],
      },
      headers: {'Idempotency-Key': newIdempotencyKey('customer-reservation')},
    );
    return LotteryReservation.fromJson(unwrapPayload(response.data));
  }

  Future<LotteryCart> cart() async {
    final response = await _api.get<Map<String, dynamic>>('/customer/cart');
    return LotteryCart.fromJson(response.data);
  }

  Future<LotteryCart> releaseReservation(String reservationId) async {
    await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/reservations/$reservationId/release',
      data: const {},
      headers: {
        'Idempotency-Key': newIdempotencyKey('customer-reservation-release'),
      },
    );
    return cart();
  }

  Future<LotteryCheckoutOrder> checkout(List<String> reservationIds) async {
    final ids = reservationIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final response = await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/checkout',
      data: {
        'reservation_id': ids.isEmpty ? '' : ids.first,
        'reservation_ids': ids,
        'payment_method': 'wallet',
      },
      headers: {'Idempotency-Key': newIdempotencyKey('customer-checkout')},
    );
    return LotteryCheckoutOrder.fromJson(response.data);
  }
}

String _normalizeSearchNumber(String value) {
  return value.replaceAll(RegExp(r'\D'), '').substringSafe(0, 6);
}

List<String> _normalizeDigits(List<String> values) {
  return List.generate(6, (index) {
    if (index >= values.length) return '';
    final digit = values[index].replaceAll(RegExp(r'\D'), '');
    return digit.isEmpty ? '' : digit.substringSafe(0, 1);
  });
}

extension _SafeSubstring on String {
  String substringSafe(int start, int end) {
    if (isEmpty || start >= length) return '';
    return substring(start, end > length ? length : end);
  }
}
