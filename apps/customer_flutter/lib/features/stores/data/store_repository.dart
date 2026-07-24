import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/provider_cache.dart';
import '../../results/data/result_repository.dart';
import 'store_models.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(ref.watch(apiClientProvider));
});

final storeListProvider = FutureProvider.autoDispose
    .family<StorePage, StoreListQuery>((ref, query) async {
      ref.keepForCustomerNavigation();
      return ref
          .watch(storeRepositoryProvider)
          .list(q: query.q, cursor: query.cursor);
    });

final storeLotteryProvider = FutureProvider.autoDispose
    .family<StoreLotteryPage, StoreLotteryQuery>((ref, query) async {
      ref.keepForCustomerNavigation();
      final game = await ref.watch(resultRepositoryProvider).currentGame();
      final gameId = query.gameId.isNotEmpty ? query.gameId : game?.id ?? '';
      if (gameId.isEmpty) {
        return const StoreLotteryPage(
          items: [],
          nextCursor: '',
          hasMore: false,
          gameId: '',
          sellerName: '',
        );
      }
      return ref
          .watch(storeRepositoryProvider)
          .lotteries(
            storeId: query.storeId,
            gameId: gameId,
            digits: query.digits,
            cursor: query.cursor,
          );
    });

class StoreListQuery {
  const StoreListQuery({this.q = '', this.cursor = ''});

  final String q;
  final String cursor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreListQuery &&
          runtimeType == other.runtimeType &&
          q == other.q &&
          cursor == other.cursor;

  @override
  int get hashCode => Object.hash(q, cursor);
}

class StoreLotteryQuery {
  const StoreLotteryQuery({
    required this.storeId,
    this.gameId = '',
    this.digits = const [],
    this.cursor = '',
  });

  final String storeId;
  final String gameId;
  final List<String> digits;
  final String cursor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreLotteryQuery &&
          runtimeType == other.runtimeType &&
          storeId == other.storeId &&
          gameId == other.gameId &&
          _listEquals(digits, other.digits) &&
          cursor == other.cursor;

  @override
  int get hashCode =>
      Object.hash(storeId, gameId, Object.hashAll(digits), cursor);
}

class StoreRepository {
  const StoreRepository(this._api);

  final ApiClient _api;

  Future<StorePage> list({
    String q = '',
    String cursor = '',
    int limit = 30,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/public/stores',
      auth: false,
      query: {
        'limit': limit,
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return StorePage.fromJson(asMap(response.data));
  }

  Future<StoreLotteryPage> lotteries({
    required String storeId,
    required String gameId,
    List<String> digits = const [],
    String cursor = '',
    int limit = 20,
  }) async {
    final normalizedDigits = _normalizeDigits(digits);
    final response = await _api.get<Map<String, dynamic>>(
      '/public/stock/search',
      auth: false,
      query: {
        'game_id': gameId,
        'mode': 'random',
        'limit': limit,
        if (storeId.isNotEmpty) 'store_id': storeId,
        for (var index = 0; index < normalizedDigits.length; index++)
          if (normalizedDigits[index].isNotEmpty)
            'd${index + 1}': normalizedDigits[index],
        if (cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return StoreLotteryPage.fromJson(asMap(response.data));
  }
}

List<String> _normalizeDigits(List<String> values) {
  return List.generate(6, (index) {
    if (index >= values.length) return '';
    final digit = values[index].replaceAll(RegExp(r'\D'), '');
    return digit.isEmpty ? '' : digit.substring(0, 1);
  });
}

bool _listEquals(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
