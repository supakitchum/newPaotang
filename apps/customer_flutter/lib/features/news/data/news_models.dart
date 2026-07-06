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
    final meta = _newsPageMeta(json);
    final nextCursor = _firstString(
      meta,
      const ['next_cursor', 'nextCursor', 'cursor', 'next'],
    );
    return NewsPage(
      items: _newsRows(json)
          .map(
            (row) => NewsItem.fromJson(row, resolveAssetUrl: resolveAssetUrl),
          )
          .toList(growable: false),
      nextCursor: nextCursor,
      hasMore: _boolValue(
            _firstValue(
              meta,
              const ['has_more', 'hasMore', 'has_next_page', 'hasNextPage'],
            ),
          ) &&
          nextCursor != null &&
          nextCursor.isNotEmpty,
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
    this.detailImageUrl = '',
    this.displayEndAt,
  });

  factory NewsItem.fromJson(
    Map<String, dynamic> json, {
    String Function(String value) resolveAssetUrl = _identity,
  }) {
    final payload = _unwrapNewsItem(json);
    final coverUrl = _firstNewsString(
          payload,
          const [
            'image_thumb_url',
            'imageThumbUrl',
            'thumbnail_url',
            'thumbnailUrl',
            'thumb_url',
            'thumbUrl',
            'cover',
            'cover_url',
            'coverUrl',
            'image_url',
            'imageUrl',
            'image',
            'image_full_url',
            'imageFullUrl',
            'banner',
            'banner_url',
            'bannerUrl',
          ],
          nestedKeys: _newsMediaWrapperKeys,
          nestedValueKeys: _newsThumbnailValueKeys,
        ) ??
        '';
    final detailImageUrl = _firstNewsString(
          payload,
          const [
            'image_full_url',
            'imageFullUrl',
            'full_image_url',
            'fullImageUrl',
            'image_url',
            'imageUrl',
            'cover_url',
            'coverUrl',
            'cover',
            'image_thumb_url',
            'imageThumbUrl',
            'thumbnail_url',
            'thumbnailUrl',
            'image',
            'banner',
            'banner_url',
            'bannerUrl',
          ],
          nestedKeys: _newsMediaWrapperKeys,
          nestedValueKeys: _newsFullImageValueKeys,
        ) ??
        '';

    return NewsItem(
      id: _firstString(payload, const [
            'id',
            'news_id',
            'newsId',
            'announcement_id',
            'announcementId',
          ]) ??
          '',
      title: _firstNewsString(
            payload,
            const ['title', 'headline', 'name'],
            nestedKeys: const ['seo', 'metadata', 'meta'],
            nestedValueKeys: const ['title', 'headline', 'name'],
          ) ??
          '',
      summary: _firstString(
            payload,
            const [
              'detail',
              'summary',
              'description',
              'excerpt',
              'short_description',
              'shortDescription',
            ],
          ) ??
          '',
      body: _firstString(
            payload,
            const [
              'body',
              'content',
              'html',
              'article',
              'detail',
              'summary',
              'description',
            ],
          ) ??
          '',
      slug: _firstNewsString(
            payload,
            const ['slug', 'news_slug', 'newsSlug', 'permalink'],
            nestedKeys: const ['seo', 'target', 'link', 'links', 'metadata'],
            nestedValueKeys: const ['slug', 'newsSlug', 'path', 'permalink'],
          ) ??
          '',
      url: _firstNewsString(
            payload,
            const [
              'url',
              'link',
              'href',
              'target_url',
              'targetUrl',
              'external_url',
              'externalUrl',
              'action_url',
              'actionUrl',
              'web_url',
              'webUrl',
              'deep_link',
              'deepLink',
            ],
            nestedKeys: const [
              'target',
              'cta',
              'action',
              'link',
              'links',
              'button',
              'primaryAction',
              'primary_action',
            ],
            nestedValueKeys: const [
              'url',
              'href',
              'link',
              'targetUrl',
              'target_url',
              'externalUrl',
              'external_url',
              'actionUrl',
              'action_url',
              'webUrl',
              'web_url',
              'deepLink',
              'deep_link',
            ],
          ) ??
          '',
      coverUrl: _resolveImageUrl(coverUrl, resolveAssetUrl),
      detailImageUrl: _resolveImageUrl(detailImageUrl, resolveAssetUrl),
      publishedAt: _firstValue(payload, const [
        'display_start_at',
        'displayStartAt',
        'published_at',
        'publishedAt',
        'created_at',
        'createdAt',
        'updated_at',
        'updatedAt',
      ]),
      displayEndAt: _firstValue(payload, const [
        'display_end_at',
        'displayEndAt',
      ]),
    );
  }

  final String id;
  final String title;
  final String summary;
  final String body;
  final String slug;
  final String url;
  final String coverUrl;
  final String detailImageUrl;
  final Object? publishedAt;
  final Object? displayEndAt;
}

String _identity(String value) => value;

String _resolveImageUrl(
  String value,
  String Function(String value) resolveAssetUrl,
) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '' : resolveAssetUrl(trimmed);
}

List<Map<String, dynamic>> _newsRows(Object? value, [int depth = 0]) {
  if (value is List) return asMapList(value);
  final rows = unwrapDataList(value);
  if (rows.isNotEmpty) return rows;
  if (depth >= 5) return const [];

  final payload = asMap(value);
  if (payload.isEmpty) return const [];

  for (final key in const [
    'news',
    'announcements',
    'news_items',
    'newsItems',
    'rows',
    'items',
    'data',
    'result',
    'resource',
    'newsPage',
    'announcementPage',
  ]) {
    if (!payload.containsKey(key)) continue;
    final nestedRows = _newsRows(payload[key], depth + 1);
    if (nestedRows.isNotEmpty || payload[key] is List) return nestedRows;
  }

  return const [];
}

Map<String, dynamic> _newsPageMeta(Object? value, [int depth = 0]) {
  final meta = Map<String, dynamic>.from(unwrapMeta(value));
  if (_hasPageMeta(meta)) return meta;
  if (depth >= 5) return meta;

  final payload = asMap(value);
  if (payload.isEmpty) return meta;

  for (final key in const ['pagination', 'pageInfo', 'page_info', 'paging']) {
    final candidate = asMap(payload[key]);
    if (_hasPageMeta(candidate)) return candidate;
  }

  for (final key in const [
    'data',
    'result',
    'resource',
    'newsPage',
    'announcementPage',
    'news',
    'announcements',
  ]) {
    if (!payload.containsKey(key)) continue;
    final nestedMeta = _newsPageMeta(payload[key], depth + 1);
    if (_hasPageMeta(nestedMeta)) return nestedMeta;
  }

  return meta;
}

Map<String, dynamic> _unwrapNewsItem(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 5) return json;

  for (final key in const [
    'news',
    'news_item',
    'newsItem',
    'announcement',
    'item',
    'resource',
    'data',
    'result',
  ]) {
    final candidate = asMap(json[key]);
    if (candidate.isEmpty) continue;
    if (_looksLikeNewsItem(candidate) || !_looksLikeNewsItem(json)) {
      return _unwrapNewsItem(candidate, depth + 1);
    }
  }

  return json;
}

bool _looksLikeNewsItem(Map<String, dynamic> value) {
  return const [
    'title',
    'headline',
    'name',
    'slug',
    'newsSlug',
    'url',
    'link',
    'href',
    'target',
    'targetUrl',
    'externalUrl',
    'actionUrl',
    'media',
    'asset',
    'assets',
    'image_thumb_url',
    'imageThumbUrl',
    'thumbnailUrl',
    'cover',
    'cover_url',
    'coverUrl',
    'image_full_url',
    'imageFullUrl',
    'imageUrl',
    'bannerUrl',
    'display_start_at',
    'displayStartAt',
  ].any(value.containsKey);
}

bool _hasPageMeta(Map<String, dynamic> value) {
  return const [
    'next_cursor',
    'nextCursor',
    'cursor',
    'next',
    'has_more',
    'hasMore',
    'has_next_page',
    'hasNextPage',
  ].any(value.containsKey);
}

Object? _firstValue(Map<String, dynamic> value, List<String> keys) {
  for (final key in keys) {
    if (!value.containsKey(key)) continue;
    final candidate = value[key];
    if (candidate != null) return candidate;
  }
  return null;
}

String? _firstString(Map<String, dynamic> value, List<String> keys) {
  for (final key in keys) {
    if (!value.containsKey(key)) continue;
    final candidate = _scalarString(value[key]);
    if (candidate != null) return candidate;
  }
  return null;
}

String? _firstNewsString(
  Map<String, dynamic> value,
  List<String> directKeys, {
  List<String> nestedKeys = const [],
  List<String> nestedValueKeys = const [],
}) {
  final direct = _firstString(value, directKeys);
  if (direct != null) return direct;

  final valueKeys = nestedValueKeys.isEmpty ? directKeys : nestedValueKeys;
  for (final key in nestedKeys) {
    final nested = asMap(value[key]);
    if (nested.isEmpty) continue;
    final nestedDirect = _firstString(nested, valueKeys);
    if (nestedDirect != null) return nestedDirect;
  }
  return null;
}

String? _scalarString(Object? value) {
  if (value == null || value is Map || value is Iterable) return null;
  final candidate = value.toString().trim();
  if (candidate.isEmpty) return null;
  return candidate;
}

bool _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes' || text == 'y';
}

const _newsMediaWrapperKeys = [
  'media',
  'mediaItem',
  'media_item',
  'image',
  'cover',
  'thumbnail',
  'thumb',
  'banner',
  'asset',
  'assets',
  'openGraph',
  'open_graph',
  'og',
  'seo',
];

const _newsThumbnailValueKeys = [
  'image_thumb_url',
  'imageThumbUrl',
  'thumbnail_url',
  'thumbnailUrl',
  'thumb_url',
  'thumbUrl',
  'url',
  'href',
  'src',
  'source',
  'path',
  'assetUrl',
  'asset_url',
  'publicUrl',
  'public_url',
  'coverUrl',
  'cover_url',
  'imageUrl',
  'image_url',
];

const _newsFullImageValueKeys = [
  'image_full_url',
  'imageFullUrl',
  'full_image_url',
  'fullImageUrl',
  'fullUrl',
  'full_url',
  'url',
  'href',
  'src',
  'source',
  'path',
  'assetUrl',
  'asset_url',
  'publicUrl',
  'public_url',
  'coverUrl',
  'cover_url',
  'imageUrl',
  'image_url',
  'thumbnailUrl',
  'thumbnail_url',
];
