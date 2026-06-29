import '../../../core/utils/api_payload.dart';

class NewsPage {
  const NewsPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory NewsPage.fromJson(
    Object? json, {
    String Function(String value) resolveAssetUrl = _identity,
  }) {
    final meta = unwrapMeta(json);
    return NewsPage(
      items: unwrapDataList(json)
          .map(
            (row) => NewsItem.fromJson(row, resolveAssetUrl: resolveAssetUrl),
          )
          .toList(growable: false),
      nextCursor: meta['next_cursor']?.toString(),
      hasMore: meta['has_more'] == true && meta['next_cursor'] != null,
    );
  }

  final List<NewsItem> items;
  final String? nextCursor;
  final bool hasMore;
}

class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.slug,
    required this.url,
    required this.coverUrl,
    required this.publishedAt,
  });

  factory NewsItem.fromJson(
    Map<String, dynamic> json, {
    String Function(String value) resolveAssetUrl = _identity,
  }) {
    final coverUrl = (json['image_thumb_url'] ??
                json['cover'] ??
                json['cover_url'] ??
                json['image_full_url'])
            ?.toString() ??
        '';

    return NewsItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: (json['detail'] ?? json['summary'])?.toString() ?? '',
      body:
          (json['body'] ?? json['content'] ?? json['detail'] ?? json['summary'])
                  ?.toString() ??
              '',
      slug: json['slug']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      coverUrl: resolveAssetUrl(coverUrl),
      publishedAt:
          json['display_start_at'] ?? json['created_at'] ?? json['updated_at'],
    );
  }

  final String id;
  final String title;
  final String summary;
  final String body;
  final String slug;
  final String url;
  final String coverUrl;
  final Object? publishedAt;
}

String _identity(String value) => value;
