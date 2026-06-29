import 'dart:io';

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/lottery/data/lottery_repository.dart';
import 'package:customer_flutter/features/stores/data/store_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer stock search repositories always request random ordering', () {
    final repositorySources = {
      'lottery': File('lib/features/lottery/data/lottery_repository.dart')
          .readAsStringSync(),
      'stores': File('lib/features/stores/data/store_repository.dart')
          .readAsStringSync(),
    };

    for (final entry in repositorySources.entries) {
      expect(
        entry.value,
        contains("'mode': 'random'"),
        reason:
            '${entry.key} stock search must not expose ordered browse mode to customer clients.',
      );
      expect(
        entry.value,
        isNot(contains("'mode': 'browse'")),
        reason:
            '${entry.key} stock search must stay randomized for production customer UI.',
      );
    }
  });

  test('lottery search sends random mode and never exposes ordering inputs',
      () async {
    final api = _CapturingApiClient();
    final repository = LotteryRepository(api);

    await repository.search(
      gameId: 'game_1',
      number: '273707',
      storeId: 'store_1',
      cursor: 'cursor_1',
    );

    expect(api.path, '/public/stock/search');
    expect(api.auth, isFalse);
    expect(api.query['mode'], 'random');
    expect(api.query['number'], '273707');
    expect(api.query['store_id'], 'store_1');
    expect(api.query['cursor'], 'cursor_1');
    expect(api.query.containsKey('sort'), isFalse);
    expect(api.query.containsKey('order'), isFalse);
  });

  test('store lottery search sends random mode and no ordered browse option',
      () async {
    final api = _CapturingApiClient();
    final repository = StoreRepository(api);

    await repository.lotteries(
      storeId: 'store_1',
      gameId: 'game_1',
      cursor: 'cursor_2',
    );

    expect(api.path, '/public/stock/search');
    expect(api.auth, isFalse);
    expect(api.query['mode'], 'random');
    expect(api.query['store_id'], 'store_1');
    expect(api.query['cursor'], 'cursor_2');
    expect(api.query.containsKey('sort'), isFalse);
    expect(api.query.containsKey('order'), isFalse);
  });
}

class _CapturingApiClient extends ApiClient {
  _CapturingApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  String path = '';
  bool auth = true;
  Map<String, dynamic> query = {};

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    this.path = path;
    this.auth = auth;
    this.query = Map<String, dynamic>.from(query ?? const {});

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'data': [],
        'meta': {
          'game_id': this.query['game_id']?.toString() ?? '',
          'next_cursor': null,
          'has_more': false,
        },
      } as T,
    );
  }
}
