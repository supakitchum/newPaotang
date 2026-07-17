import 'dart:collection';

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/results/data/result_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current result uses current-game live source and published history',
      () async {
    final api = _ResultApiClient({
      '/public/games/current': [_gamePayload('game_current')],
      '/public/results/live/game_current': [
        _resultPayload('game_current', '123456'),
      ],
      '/public/results/latest': [
        _resultPayload('game_previous', '654321'),
      ],
    });

    final bundle = await ResultRepository(api).current();

    expect(bundle.currentGame?.id, 'game_current');
    expect(bundle.selectedResult?.id, 'game_current');
    expect(bundle.selectedResult?.summary.first, '123456');
    expect(bundle.history.single.id, 'game_previous');
    expect(api.paths, [
      '/public/games/current',
      '/public/results/live/game_current',
      '/public/results/latest',
    ]);
  });

  test('current result falls back from missing live data to published game',
      () async {
    final api = _ResultApiClient({
      '/public/games/current': [_gamePayload('game_current')],
      '/public/results/live/game_current': [
        _apiException(
          '/public/results/live/game_current',
          statusCode: 404,
          code: 'result_not_found',
        ),
      ],
      '/public/results/game_current': [
        _resultPayload('game_current', '287184'),
      ],
      '/public/results/latest': [
        _resultPayload('game_current', '287184'),
      ],
    });

    final bundle = await ResultRepository(api).current();

    expect(bundle.selectedResult?.summary.first, '287184');
    expect(bundle.history, isEmpty);
    expect(api.paths, [
      '/public/games/current',
      '/public/results/live/game_current',
      '/public/results/game_current',
      '/public/results/latest',
    ]);
  });

  test('current result keeps pending current game when both sources are 404',
      () async {
    final api = _ResultApiClient({
      '/public/games/current': [_gamePayload('game_pending')],
      '/public/results/live/game_pending': [
        _apiException(
          '/public/results/live/game_pending',
          statusCode: 404,
          code: 'result_not_found',
        ),
      ],
      '/public/results/game_pending': [
        _apiException(
          '/public/results/game_pending',
          statusCode: 404,
          code: 'result_not_found',
        ),
      ],
      '/public/results/latest': [
        _apiException(
          '/public/results/latest',
          statusCode: 404,
          code: 'result_not_found',
        ),
      ],
    });

    final bundle = await ResultRepository(api).current();

    expect(bundle.selectedResult?.id, 'game_pending');
    expect(bundle.selectedResult?.hasResolvedResult, isFalse);
    expect(bundle.history, isEmpty);
  });

  test('current result propagates operational result errors', () async {
    final maintenance = _apiException(
      '/public/results/live/game_current',
      statusCode: 503,
      code: 'maintenance_active',
    );
    final api = _ResultApiClient({
      '/public/games/current': [_gamePayload('game_current')],
      '/public/results/live/game_current': [maintenance],
    });

    await expectLater(
      ResultRepository(api).current(),
      throwsA(same(maintenance)),
    );
  });

  test('current result preserves ordinary backend error after fallbacks fail',
      () async {
    final publishedError = _apiException(
      '/public/results/game_current',
      statusCode: 503,
      code: 'result_unavailable',
      message: 'ระบบผลรางวัลยังไม่พร้อมใช้งาน',
    );
    final api = _ResultApiClient({
      '/public/games/current': [_gamePayload('game_current')],
      '/public/results/live/game_current': [
        _apiException(
          '/public/results/live/game_current',
          statusCode: 502,
          code: 'live_result_unavailable',
        ),
      ],
      '/public/results/game_current': [publishedError],
    });

    await expectLater(
      ResultRepository(api).current(),
      throwsA(same(publishedError)),
    );
  });

  test('legacy index uses latest live source without current-game lookup',
      () async {
    final api = _ResultApiClient({
      '/public/results/live/latest': [
        _resultPayload('game_legacy', '111222'),
      ],
    });

    final bundle = await ResultRepository(api).legacy();

    expect(bundle.currentGame, isNull);
    expect(bundle.selectedResult?.id, 'game_legacy');
    expect(bundle.history.single.id, 'game_legacy');
    expect(api.paths, ['/public/results/live/latest']);
  });

  test('legacy detail uses published-only encoded game source', () async {
    final api = _ResultApiClient({
      '/public/results/game%20%2F%201': [
        _resultPayload('game / 1', '999888'),
      ],
    });

    final bundle = await ResultRepository(api).published(gameId: 'game / 1');

    expect(bundle.selectedResult?.id, 'game / 1');
    expect(bundle.selectedResult?.summary.first, '999888');
    expect(api.paths, ['/public/results/game%20%2F%201']);
  });
}

Map<String, dynamic> _gamePayload(String id) {
  return {
    'data': {
      'id': id,
      'name': 'งวดทดสอบ',
      'status': 'closed',
      'draw_at': '2026-07-16T16:00:00+07:00',
    },
  };
}

Map<String, dynamic> _resultPayload(String id, String firstPrize) {
  return {
    'data': {
      'game_id': id,
      'game_name': 'งวดทดสอบ',
      'status': 'published',
      'official_status': 'published',
      'completion_percent': 100,
      'prizes': [
        {
          'prize_type': 'first_prize',
          'prize_number': firstPrize,
          'amount': 6000000,
        },
      ],
    },
  };
}

DioException _apiException(
  String path, {
  required int statusCode,
  required String code,
  String message = 'API unavailable',
}) {
  final request = RequestOptions(path: path);
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: statusCode,
      data: {
        'error': {
          'code': code,
          'message': message,
        },
      },
    ),
  );
}

class _ResultApiClient extends ApiClient {
  _ResultApiClient(Map<String, List<Object>> responses)
      : responses = responses.map(
          (path, values) => MapEntry(path, Queue<Object>.from(values)),
        ),
        super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final Map<String, Queue<Object>> responses;
  final paths = <String>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    paths.add(path);
    final queue = responses[path];
    if (queue == null || queue.isEmpty) {
      throw StateError('Unexpected GET $path');
    }
    final value = queue.removeFirst();
    if (value is Exception) throw value;
    if (value is Error) throw value;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: value as T,
    );
  }
}
