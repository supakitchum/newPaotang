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
  return ref.watch(activityRepositoryProvider).list(
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
    .family<List<ActivityItem>, String>((ref, gameId) async {
  final auth = ref.watch(authControllerProvider);
  return ref.watch(activityRepositoryProvider).list(
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
    final page = await ref.watch(activityRepositoryProvider).awards(limit: 100);
    return page.items
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

  final ApiClient _api;
  final String Function(String value) _resolveAssetUrl;

  Future<List<ActivityItem>> list({
    int limit = 30,
    bool authenticated = false,
    bool history = false,
    String gameId = '',
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      authenticated ? '/customer/activities' : '/public/activities',
      auth: authenticated,
      query: {
        'limit': limit,
        if (history) 'history': 1,
        if (gameId.isNotEmpty) 'game_id': gameId,
      },
    );
    return unwrapDataList(
      response.data,
    )
        .map(
          (row) =>
              ActivityItem.fromJson(row, resolveAssetUrl: _resolveAssetUrl),
        )
        .toList(
          growable: false,
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

  Future<ActivityAwardPage> awards({int limit = 100, String? status}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/activity-awards',
      query: {
        'limit': limit,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return ActivityAwardPage.fromJson(asMap(response.data));
  }
}
