import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/activities/data/activity_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authenticated history list requests cursor pagination endpoint',
      () async {
    final api = _ActivityApiClient();
    final repository = ActivityRepository(api, (value) => 'asset:$value');

    final page = await repository.listPage(
      authenticated: true,
      history: true,
      gameId: 'game_1',
      cursor: 'cursor_1',
      limit: 12,
    );

    expect(api.path, '/customer/activities');
    expect(api.auth, isTrue);
    expect(api.query, {
      'limit': 12,
      'cursor': 'cursor_1',
      'history': 1,
      'game_id': 'game_1',
    });
    expect(page.meta.hasMore, isTrue);
    expect(page.meta.nextCursor, 'cursor_2');
    expect(page.meta.selectedGameId, 'game_1');
    expect(page.meta.games.single.id, 'game_1');
    expect(page.items.single.id, 'act_1');
    expect(page.items.single.imageUrl, 'asset:/storage/activity.webp');
    expect(page.items.single.hasRight, isTrue);
  });

  test('public current list omits cursor when cursor is blank', () async {
    final api = _ActivityApiClient();
    final repository = ActivityRepository(api, (value) => value);

    final page = await repository.listPage(
      authenticated: false,
      cursor: '   ',
      limit: 6,
    );

    expect(api.path, '/public/activities');
    expect(api.auth, isFalse);
    expect(api.query, {'limit': 6});
    expect(page.meta.hasMore, isTrue);
    expect(page.items.single.slug, 'cashback-5');
  });

  test('listAll loads every activity page by cursor', () async {
    final api = _ActivityApiClient();
    final repository = ActivityRepository(api, (value) => value);

    final activities = await repository.listAll(
      authenticated: true,
      limit: 1,
    );

    expect(activities.map((activity) => activity.id), ['act_1', 'act_2']);
    expect(api.calls, [
      const _ApiCall(
        path: '/customer/activities',
        auth: true,
        query: {'limit': 1},
      ),
      const _ApiCall(
        path: '/customer/activities',
        auth: true,
        query: {'limit': 1, 'cursor': 'cursor_2'},
      ),
    ]);
  });

  test('listAll stops when backend repeats the same cursor', () async {
    final api = _ActivityApiClient(repeatActivityCursor: true);
    final repository = ActivityRepository(api, (value) => value);

    final activities = await repository.listAll(limit: 1, maxPages: 5);

    expect(activities.map((activity) => activity.id), ['act_1', 'act_2']);
    expect(api.calls, [
      const _ApiCall(
        path: '/public/activities',
        auth: false,
        query: {'limit': 1},
      ),
      const _ApiCall(
        path: '/public/activities',
        auth: false,
        query: {'limit': 1, 'cursor': 'cursor_2'},
      ),
    ]);
  });

  test('awardsAll loads every award page by cursor and status', () async {
    final api = _ActivityApiClient();
    final repository = ActivityRepository(api, (value) => value);

    final awards = await repository.awardsAll(limit: 1, status: 'claimable');

    expect(awards.map((award) => award.id), ['award_1', 'award_2']);
    expect(api.calls, [
      const _ApiCall(
        path: '/customer/activity-awards',
        auth: true,
        query: {'limit': 1, 'status': 'claimable'},
      ),
      const _ApiCall(
        path: '/customer/activity-awards',
        auth: true,
        query: {
          'limit': 1,
          'cursor': 'award_cursor_2',
          'status': 'claimable',
        },
      ),
    ]);
  });

  test('awardsAll stops when backend repeats the same cursor', () async {
    final api = _ActivityApiClient(repeatAwardCursor: true);
    final repository = ActivityRepository(api, (value) => value);

    final awards = await repository.awardsAll(limit: 1, maxPages: 5);

    expect(awards.map((award) => award.id), ['award_1', 'award_2']);
    expect(api.calls, [
      const _ApiCall(
        path: '/customer/activity-awards',
        auth: true,
        query: {'limit': 1},
      ),
      const _ApiCall(
        path: '/customer/activity-awards',
        auth: true,
        query: {'limit': 1, 'cursor': 'award_cursor_2'},
      ),
    ]);
  });
}

class _ApiCall {
  const _ApiCall({
    required this.path,
    required this.auth,
    required this.query,
  });

  final String path;
  final bool auth;
  final Map<String, dynamic> query;

  @override
  bool operator ==(Object other) {
    return other is _ApiCall &&
        other.path == path &&
        other.auth == auth &&
        _mapsEqual(other.query, query);
  }

  @override
  int get hashCode => Object.hash(path, auth, Object.hashAll(query.entries));

  @override
  String toString() => '_ApiCall(path: $path, auth: $auth, query: $query)';
}

bool _mapsEqual(Map<String, dynamic> left, Map<String, dynamic> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

class _ActivityApiClient extends ApiClient {
  _ActivityApiClient({
    this.repeatActivityCursor = false,
    this.repeatAwardCursor = false,
  }) : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final bool repeatActivityCursor;
  final bool repeatAwardCursor;
  String path = '';
  Map<String, dynamic> query = {};
  bool auth = true;
  final List<_ApiCall> calls = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    this.path = path;
    this.query = Map<String, dynamic>.from(query ?? {});
    this.auth = auth;
    calls.add(_ApiCall(path: path, auth: auth, query: this.query));

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (path == '/customer/activity-awards'
          ? _awardPayload(this.query, repeatCursor: repeatAwardCursor)
          : _activityPayload(
              this.query,
              repeatCursor: repeatActivityCursor,
            )) as T,
    );
  }
}

Map<String, dynamic> _activityPayload(
  Map<String, dynamic> query, {
  bool repeatCursor = false,
}) {
  final isSecondPage = query['cursor']?.toString() == 'cursor_2';
  final nextCursor =
      repeatCursor && isSecondPage ? query['cursor']?.toString() : 'cursor_2';
  return {
    'data': [
      {
        'id': isSecondPage ? 'act_2' : 'act_1',
        'name': isSecondPage ? 'Lucky Board' : 'Cashback 5%',
        'slug': isSecondPage ? 'lucky-board' : 'cashback-5',
        'type': isSecondPage ? 'lucky_board' : 'cashback',
        'summary': isSecondPage
            ? 'Pick your lucky number.'
            : 'Spend and receive cashback.',
        'image_thumb_url': '/storage/activity.webp',
        'cashback_progress': {
          'is_eligible': !isSecondPage,
          'estimated_amount': {'amount': 5000, 'currency': 'THB'},
        },
      },
    ],
    'meta': {
      'has_more': !isSecondPage,
      'next_cursor': isSecondPage ? null : nextCursor,
      'selected_game_id': 'game_1',
      'current_game_id': 'game_1',
      'has_history': true,
      'games': [
        {'id': 'game_1', 'label': 'งวด 1'},
      ],
    },
  };
}

Map<String, dynamic> _awardPayload(
  Map<String, dynamic> query, {
  bool repeatCursor = false,
}) {
  final isSecondPage = query['cursor']?.toString() == 'award_cursor_2';
  final nextCursor = repeatCursor && isSecondPage
      ? query['cursor']?.toString()
      : 'award_cursor_2';
  return {
    'data': [
      {
        'id': isSecondPage ? 'award_2' : 'award_1',
        'activity_id': isSecondPage ? 'act_2' : 'act_1',
        'activity_name': isSecondPage ? 'Lucky Board' : 'Cashback 5%',
        'type': isSecondPage ? 'lucky_board' : 'cashback',
        'amount': {'amount': isSecondPage ? 100000 : 5000, 'currency': 'THB'},
        'status': 'claimable',
      },
    ],
    'meta': {
      'has_more': !isSecondPage,
      'next_cursor': isSecondPage ? null : nextCursor,
    },
  };
}
