import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/asset_url.dart';
import 'news_models.dart';

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  final resolveAssetUrl = ref.watch(assetUrlResolverProvider);
  return NewsRepository(
    ref.watch(apiClientProvider),
    resolveAssetUrl.call,
  );
});

final newsListProvider = FutureProvider<List<NewsItem>>((ref) async {
  return ref.watch(newsRepositoryProvider).list();
});

final newsDetailProvider = FutureProvider.family<NewsItem, String>((
  ref,
  slug,
) async {
  return ref.watch(newsRepositoryProvider).detail(slug);
});

class NewsRepository {
  const NewsRepository(this._api, this._resolveAssetUrl);

  final ApiClient _api;
  final String Function(String value) _resolveAssetUrl;

  Future<List<NewsItem>> list({int limit = 10}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/public/news',
      auth: false,
      query: {'limit': limit},
    );
    return unwrapDataList(
      response.data,
    )
        .map((row) => NewsItem.fromJson(row, resolveAssetUrl: _resolveAssetUrl))
        .toList(
          growable: false,
        );
  }

  Future<NewsItem> detail(String slug) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/public/news/$slug',
      auth: false,
    );
    return NewsItem.fromJson(
      unwrapPayload(response.data),
      resolveAssetUrl: _resolveAssetUrl,
    );
  }

  Future<NewsItem?> modal() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/public/news/modal',
      auth: false,
    );
    final payload = unwrapPayload(response.data);
    if (payload.isEmpty) return null;

    final item = NewsItem.fromJson(payload, resolveAssetUrl: _resolveAssetUrl);
    return item.coverUrl.isEmpty ? null : item;
  }
}
