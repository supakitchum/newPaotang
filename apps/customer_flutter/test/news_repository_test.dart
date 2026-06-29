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
