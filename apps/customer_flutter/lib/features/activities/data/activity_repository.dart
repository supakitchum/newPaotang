import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/asset_url.dart';
import '../../../core/utils/idempotency_key.dart';
import 'activity_models.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final resolveAssetUrl = ref.watch(assetUrlResolverProvider);
  return ActivityRepository(
    ref.watch(apiClientProvider),
    resolveAssetUrl.call,
  );
});

final activityListProvider = FutureProvider<List<ActivityItem>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  return ref.watch(activityRepositoryProvider).listAll(
        authenticated: auth.isAuthenticated && !auth.pinRequired,
      );
});

final activityListPageProvider =
    FutureProvider.autoDispose<ActivityListPage>((ref) async {
  final auth = ref.watch(authControllerProvider);
  return ref.watch(activityRepositoryProvider).listPage(
        authenticated: auth.isAuthenticated && !auth.pinRequired,
      );
});

final activityDetailProvider =
    FutureProvider.family<ActivityItem, ActivityDetailRequest>((ref, request) {
  return ref.watch(activityRepositoryProvider).detail(
        request.slug,
        authenticated: request.authenticated,
      );
});

final activityHistoryProvider = FutureProvider.autoDispose
    .family<ActivityListPage, String>((ref, gameId) async {
  final auth = ref.watch(authControllerProvider);
  return ref.watch(activityRepositoryProvider).listPage(
        authenticated: auth.isAuthenticated && !auth.pinRequired,
        history: true,
        gameId: gameId,
      );
});

final activityAwardListProvider =
    FutureProvider.autoDispose.family<List<ActivityAwardItem>, String>(
  (ref, activityId) async {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isAuthenticated || auth.pinRequired) return const [];
    final awards = await ref.watch(activityRepositoryProvider).awardsAll();
    return awards
        .where((award) => award.activityId == activityId)
        .toList(growable: false);
  },
);

class ActivityDetailRequest {
  const ActivityDetailRequest({
    required this.slug,
    required this.authenticated,
  });

  final String slug;
  final bool authenticated;

  @override
  bool operator ==(Object other) {
    return other is ActivityDetailRequest &&
        other.slug == slug &&
        other.authenticated == authenticated;
  }

  @override
  int get hashCode => Object.hash(slug, authenticated);
}

class ActivityRepository {
  const ActivityRepository(this._api, this._resolveAssetUrl);

  static const int defaultPageLimit = 30;
  static const int maxAutoPages = 10;
  static const int defaultAwardPageLimit = 100;
  static const int maxAwardAutoPages = 10;

  final ApiClient _api;
  final String Function(String value) _resolveAssetUrl;

  Future<List<ActivityItem>> list({
    int limit = defaultPageLimit,
    bool authenticated = false,
    bool history = false,
    String gameId = '',
  }) async {
    final page = await listPage(
      limit: limit,
      authenticated: authenticated,
      history: history,
      gameId: gameId,
    );
    return page.items;
  }

  Future<List<ActivityItem>> listAll({
    int limit = defaultPageLimit,
    int maxPages = maxAutoPages,
    bool authenticated = false,
    bool history = false,
    String gameId = '',
  }) async {
    final items = <ActivityItem>[];
    var cursor = '';

    for (var pageIndex = 0; pageIndex < maxPages; pageIndex++) {
      final page = await listPage(
        limit: limit,
        cursor: cursor,
        authenticated: authenticated,
        history: history,
        gameId: gameId,
      );
      items.addAll(page.items);

      final nextCursor = page.meta.nextCursor?.trim() ?? '';
      if (!page.meta.hasMore || nextCursor.isEmpty || nextCursor == cursor) {
        break;
      }
      cursor = nextCursor;
    }

    return items;
  }

  Future<ActivityListPage> listPage({
    int limit = defaultPageLimit,
    String cursor = '',
    bool authenticated = false,
    bool history = false,
    String gameId = '',
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      authenticated ? '/customer/activities' : '/public/activities',
      auth: authenticated,
      query: {
        'limit': limit,
        if (cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
        if (history) 'history': 1,
        if (gameId.isNotEmpty) 'game_id': gameId,
      },
    );
    return ActivityListPage.fromJson(
      asMap(response.data),
      resolveAssetUrl: _resolveAssetUrl,
    );
  }

  Future<ActivityItem> detail(String slug, {bool authenticated = false}) async {
    final publicResponse = await _api.get<Map<String, dynamic>>(
      '/public/activities/$slug',
      auth: false,
    );
    var item = ActivityItem.fromJson(
      unwrapPayload(publicResponse.data),
      resolveAssetUrl: _resolveAssetUrl,
    );

    if (!authenticated || item.id.isEmpty) return item;

    final response = await _api.get<Map<String, dynamic>>(
      '/customer/activities/${item.id}',
    );
    item = ActivityItem.fromJson(
      unwrapPayload(response.data),
      resolveAssetUrl: _resolveAssetUrl,
    );
    return item;
  }

  Future<ActivityEntry> createEntry({
    required String activityId,
    required String predictionType,
    required String selectedNumber,
  }) async {
    final response = await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/activities/$activityId/entries',
      headers: {
        'Idempotency-Key': newIdempotencyKey('customer_activity_entry'),
      },
      data: {
        'prediction_type': predictionType,
        'selected_number': selectedNumber,
      },
    );
    return ActivityEntry.fromJson(unwrapPayload(response.data));
  }

  Future<ActivityAwardPage> awards({
    int limit = defaultAwardPageLimit,
    String cursor = '',
    String? status,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/activity-awards',
      query: {
        'limit': limit,
        if (cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return ActivityAwardPage.fromJson(asMap(response.data));
  }

  Future<List<ActivityAwardItem>> awardsAll({
    int limit = defaultAwardPageLimit,
    int maxPages = maxAwardAutoPages,
    String? status,
  }) async {
    final items = <ActivityAwardItem>[];
    var cursor = '';

    for (var pageIndex = 0; pageIndex < maxPages; pageIndex++) {
      final page = await awards(
        limit: limit,
        cursor: cursor,
        status: status,
      );
      items.addAll(page.items);

      final nextCursor = page.nextCursor?.trim() ?? '';
      if (!page.hasMore || nextCursor.isEmpty || nextCursor == cursor) {
        break;
      }
      cursor = nextCursor;
    }

    return items;
  }
}
