import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/news/data/news_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('listAll loads every public news page by cursor', () async {
    final api = _NewsApiClient([
      {
        'data': [
          {
            'id': 'news_1',
            'title': 'ข่าวที่ 1',
            'slug': 'news-1',
            'image_thumb_url': '/storage/news/thumb-1.webp',
          },
        ],
        'meta': {
          'next_cursor': 'cursor_2',
          'has_more': true,
        },
      },
      {
        'data': [
          {
            'id': 'news_2',
            'title': 'ข่าวที่ 2',
            'slug': 'news-2',
            'image_thumb_url': '/storage/news/thumb-2.webp',
          },
        ],
        'meta': {
          'next_cursor': null,
          'has_more': false,
        },
      },
    ]);
    final repository = NewsRepository(
      api,
      (value) => 'https://cdn.example.com$value',
    );

    final news = await repository.listAll(limit: 1);

    expect(news.map((item) => item.id), ['news_1', 'news_2']);
    expect(
      news.first.coverUrl,
      'https://cdn.example.com/storage/news/thumb-1.webp',
    );
    expect(api.paths, ['/public/news', '/public/news']);
    expect(api.queries.first['limit'], 1);
    expect(api.queries.first.containsKey('cursor'), isFalse);
    expect(api.queries.last['cursor'], 'cursor_2');
  });

  test('news parser accepts production camelCase wrappers', () async {
    final api = _NewsApiClient([
      {
        'data': {
          'resource': {
            'newsPage': {
              'items': [
                {
                  'newsItem': {
                    'newsId': 'news_wrapped',
                    'headline': 'ข่าว production',
                    'seo': {'slug': 'production-news'},
                    'media': {
                      'thumbnailUrl': '/storage/news/wrapped-media.webp',
                      'fullImageUrl': '/storage/news/wrapped-full.webp',
                    },
                    'target': {
                      'href': '/news/production-news?source=bo',
                    },
                    'displayStartAt': '2026-07-01T09:30:00+07:00',
                  },
                },
              ],
              'pagination': {
                'nextCursor': 'cursor_next',
                'hasMore': 'true',
              },
            },
          },
        },
      },
      {
        'result': {
          'announcement': {
            'announcementId': 'detail_wrapped',
            'title': 'รายละเอียดข่าว',
            'description': 'สรุปข่าว',
            'content': 'ย่อหน้าแรก\n\nย่อหน้าสอง',
            'slug': 'detail-news',
            'media': {
              'thumbnailUrl': '/storage/news/detail-thumb.webp',
              'fullUrl': '/storage/news/detail-full.webp',
            },
            'displayStartAt': '2026-07-02T09:30:00+07:00',
            'displayEndAt': '2026-07-05T09:30:00+07:00',
          },
        },
      },
      {
        'data': {
          'news': {
            'id': 'modal_wrapped',
            'title': 'ข่าวหน้าหลัก',
            'slug': 'modal-news',
            'assets': {'publicUrl': '/storage/news/modal.webp'},
          },
        },
      },
    ]);
    final repository = NewsRepository(
      api,
      (value) => 'https://cdn.example.com$value',
    );

    final page = await repository.listPage(limit: 1);
    final detail = await repository.detail('detail-news');
    final modal = await repository.modal();

    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'cursor_next');
    expect(page.items.single.id, 'news_wrapped');
    expect(page.items.single.title, 'ข่าว production');
    expect(page.items.single.slug, 'production-news');
    expect(page.items.single.url, '/news/production-news?source=bo');
    expect(
      page.items.single.coverUrl,
      'https://cdn.example.com/storage/news/wrapped-media.webp',
    );
    expect(
      page.items.single.detailImageUrl,
      'https://cdn.example.com/storage/news/wrapped-full.webp',
    );
    expect(detail.id, 'detail_wrapped');
    expect(detail.summary, 'สรุปข่าว');
    expect(detail.body, 'ย่อหน้าแรก\n\nย่อหน้าสอง');
    expect(
      detail.coverUrl,
      'https://cdn.example.com/storage/news/detail-thumb.webp',
    );
    expect(
      detail.detailImageUrl,
      'https://cdn.example.com/storage/news/detail-full.webp',
    );
    expect(detail.displayEndAt, '2026-07-05T09:30:00+07:00');
    expect(modal?.id, 'modal_wrapped');
    expect(
      modal?.coverUrl,
      'https://cdn.example.com/storage/news/modal.webp',
    );
    expect(api.paths, [
      '/public/news',
      '/public/news/detail-news',
      '/public/news/modal',
    ]);
  });
}

class _NewsApiClient extends ApiClient {
  _NewsApiClient(this._responses)
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final List<Map<String, dynamic>> _responses;
  final paths = <String>[];
  final queries = <Map<String, dynamic>>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    paths.add(path);
    queries.add(Map<String, dynamic>.from(query ?? const {}));
    final index = paths.length - 1;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: _responses[index] as T,
    );
  }
}
