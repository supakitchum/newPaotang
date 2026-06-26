import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import '../../results/data/result_repository.dart';
import 'store_models.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(ref.watch(apiClientProvider));
});

final storeListProvider = FutureProvider.autoDispose
    .family<StorePage, StoreListQuery>((ref, query) async {
  return ref.watch(storeRepositoryProvider).list(
        q: query.q,
        cursor: query.cursor,
      );
});

final storeLotteryProvider = FutureProvider.autoDispose
    .family<StoreLotteryPage, StoreLotteryQuery>((ref, query) async {
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
  return ref.watch(storeRepositoryProvider).lotteries(
        storeId: query.storeId,
        gameId: gameId,
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
    this.cursor = '',
  });

  final String storeId;
  final String gameId;
  final String cursor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreLotteryQuery &&
          runtimeType == other.runtimeType &&
          storeId == other.storeId &&
          gameId == other.gameId &&
          cursor == other.cursor;

  @override
  int get hashCode => Object.hash(storeId, gameId, cursor);
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
    String cursor = '',
    int limit = 20,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/public/stock/search',
      auth: false,
      query: {
        'game_id': gameId,
        'mode': 'browse',
        'limit': limit,
        if (storeId.isNotEmpty) 'store_id': storeId,
        if (cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return StoreLotteryPage.fromJson(asMap(response.data));
  }
}
