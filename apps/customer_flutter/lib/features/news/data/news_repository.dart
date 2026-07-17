import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/asset_url.dart';
import '../../../core/utils/api_payload.dart';
import 'news_models.dart';

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  final resolveAssetUrl = ref.watch(assetUrlResolverProvider);
  return NewsRepository(
    ref.watch(apiClientProvider),
    resolveAssetUrl.call,
  );
});

final newsListProvider =
    FutureProvider.autoDispose<List<NewsItem>>((ref) async {
  return ref.watch(newsRepositoryProvider).listAll();
});

final newsDetailProvider =
    FutureProvider.autoDispose.family<NewsItem, String>((ref, slug) async {
  return ref.watch(newsRepositoryProvider).detail(slug);
});

class NewsRepository {
  const NewsRepository(this._api, this._resolveAssetUrl);

  final ApiClient _api;
  final String Function(String value) _resolveAssetUrl;

  static const int defaultPageLimit = 20;
  static const int maxAutoPages = 10;

  Future<List<NewsItem>> list({int limit = defaultPageLimit}) async {
    return listPage(limit: limit).then((page) => page.items);
  }

  Future<NewsPage> listPage({
    int limit = defaultPageLimit,
    String cursor = '',
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/public/news',
      auth: false,
      query: {
        'limit': limit,
        if (cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      },
    );
    return NewsPage.fromJson(response.data, resolveAssetUrl: _resolveAssetUrl);
  }

  Future<List<NewsItem>> listAll({
    int limit = defaultPageLimit,
    int maxPages = maxAutoPages,
  }) async {
    final items = <NewsItem>[];
    String cursor = '';

    for (var pageNumber = 0; pageNumber < maxPages; pageNumber++) {
      final page = await listPage(limit: limit, cursor: cursor);
      items.addAll(page.items);

      final nextCursor = page.nextCursor?.trim() ?? '';
      if (!page.hasMore || nextCursor.isEmpty || nextCursor == cursor) {
        break;
      }
      cursor = nextCursor;
    }

    return items;
  }

  Future<NewsItem> detail(String slug) async {
    final encodedSlug = Uri.encodeComponent(slug.trim());
    final response = await _api.get<Map<String, dynamic>>(
      '/public/news/$encodedSlug',
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
    return item.coverUrl.isEmpty && item.detailImageUrl.isEmpty ? null : item;
  }
}
