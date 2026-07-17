import 'dart:convert';
import 'dart:typed_data';

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('postWithHeaders sends write request with auth and custom headers',
      () async {
    final tokenStore = _MemoryTokenStore();
    await tokenStore.save(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      customerId: 'cus_1',
    );
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ApiClient(
      const AppConfig(
        apiBaseUrl: 'https://partner.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      tokenStore,
      localeTag: 'th-TH',
      dio: dio,
    );

    final response = await api.postWithHeaders<Map<String, dynamic>>(
      '/customer/reservations',
      data: const {
        'game_id': 'game_1',
        'local_stock_item_ids': ['stock_1'],
      },
      headers: const {'Idempotency-Key': 'reserve-key'},
    );

    expect(response.data?['ok'], isTrue);
    expect(adapter.methods, ['POST']);
    expect(adapter.paths, ['customer/reservations']);
    expect(adapter.authorizationHeaders, ['Bearer access-token']);
    expect(adapter.idempotencyHeaders, ['reserve-key']);
    expect(adapter.requestIds.single, startsWith('req_'));
    expect(adapter.bodies.single, contains('"game_id":"game_1"'));
    expect(adapter.bodies.single, contains('"local_stock_item_ids"'));
  });

  test('auth requests refresh expired access token and retry once', () async {
    final tokenStore = _MemoryTokenStore();
    await tokenStore.save(
      accessToken: 'expired-access',
      refreshToken: 'refresh-token',
      customerId: 'cus_1',
    );
    final adapter = _RefreshingAuthAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ApiClient(
      const AppConfig(
        apiBaseUrl: 'https://partner.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      tokenStore,
      localeTag: 'th-TH',
      dio: dio,
    );

    final response = await api.post<Map<String, dynamic>>(
      '/customer/auth/pin/verify',
      data: {'pin': '123456'},
    );

    expect(response.data?['ok'], isTrue);
    expect(adapter.paths, [
      'customer/auth/pin/verify',
      'customer/auth/refresh',
      'customer/auth/pin/verify',
    ]);
    expect(adapter.authorizationHeaders, [
      'Bearer expired-access',
      null,
      'Bearer fresh-access',
    ]);
    expect(adapter.requestIds[0], startsWith('req_'));
    expect(adapter.requestIds[1], startsWith('req_'));
    expect(adapter.requestIds[2], adapter.requestIds[0]);
    expect(adapter.requestIds[1], isNot(adapter.requestIds[0]));
    expect(tokenStore.accessToken, 'fresh-access');
    expect(tokenStore.refreshToken, 'fresh-refresh');
    expect(tokenStore.customerId, 'cus_1');
  });

  test('token refresh keeps the previous refresh token when rotation omits it',
      () async {
    final tokenStore = _MemoryTokenStore();
    await tokenStore.save(
      accessToken: 'expired-access',
      refreshToken: 'refresh-token',
      customerId: 'cus_1',
    );
    final adapter = _RefreshingAuthAdapter(omitRefreshToken: true);
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ApiClient(
      const AppConfig(
        apiBaseUrl: 'https://partner.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      tokenStore,
      localeTag: 'th-TH',
      dio: dio,
    );

    await api.post<Map<String, dynamic>>(
      '/customer/auth/pin/verify',
      data: {'pin': '123456'},
    );

    expect(tokenStore.accessToken, 'fresh-access');
    expect(tokenStore.refreshToken, 'refresh-token');
    expect(tokenStore.customerId, 'cus_1');
  });

  test('temporary refresh failures preserve the long-lived customer session',
      () async {
    final tokenStore = _MemoryTokenStore();
    await tokenStore.save(
      accessToken: 'expired-access',
      refreshToken: 'refresh-token',
      customerId: 'cus_1',
    );
    final adapter = _RefreshFailureAdapter(
      refreshStatus: 503,
      refreshBody: const {
        'error': {
          'code': 'service_unavailable',
          'message': 'Please try again.',
        },
      },
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ApiClient(
      const AppConfig(
        apiBaseUrl: 'https://partner.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      tokenStore,
      localeTag: 'th-TH',
      dio: dio,
    );

    await expectLater(
      api.get<Map<String, dynamic>>('/customer/wallet'),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'refresh status',
          503,
        ),
      ),
    );

    expect(adapter.paths, [
      'customer/wallet',
      'customer/auth/refresh',
    ]);
    expect(tokenStore.accessToken, 'expired-access');
    expect(tokenStore.refreshToken, 'refresh-token');
    expect(tokenStore.customerId, 'cus_1');
  });

  test('refresh suspension errors remain visible to operational routing',
      () async {
    final tokenStore = _MemoryTokenStore();
    await tokenStore.save(
      accessToken: 'expired-access',
      refreshToken: 'refresh-token',
      customerId: 'cus_1',
    );
    final adapter = _RefreshFailureAdapter(
      refreshStatus: 403,
      refreshBody: const {
        'error': {
          'code': 'customer_suspended',
          'message': 'Customer account is suspended.',
          'details': {
            'suspension': {'reason': 'Risk review'},
          },
        },
      },
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ApiClient(
      const AppConfig(
        apiBaseUrl: 'https://partner.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      tokenStore,
      localeTag: 'th-TH',
      dio: dio,
    );

    DioException? thrown;
    try {
      await api.get<Map<String, dynamic>>('/customer/wallet');
    } on DioException catch (error) {
      thrown = error;
    }

    expect(thrown?.response?.statusCode, 403);
    expect(
      (thrown?.response?.data as Map?)?['error']?['code'],
      'customer_suspended',
    );
    expect(tokenStore.accessToken, 'expired-access');
    expect(tokenStore.refreshToken, 'refresh-token');
  });

  test('rejected refresh token returns the original protected-route 401',
      () async {
    final tokenStore = _MemoryTokenStore();
    await tokenStore.save(
      accessToken: 'expired-access',
      refreshToken: 'rejected-refresh',
      customerId: 'cus_1',
    );
    final adapter = _RefreshFailureAdapter(
      refreshStatus: 401,
      refreshBody: const {
        'error': {
          'code': 'authentication_required',
          'message':
              'Authentication token is missing, invalid, expired, or revoked.',
        },
      },
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ApiClient(
      const AppConfig(
        apiBaseUrl: 'https://partner.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      tokenStore,
      localeTag: 'th-TH',
      dio: dio,
    );

    DioException? thrown;
    try {
      await api.get<Map<String, dynamic>>('/customer/wallet');
    } on DioException catch (error) {
      thrown = error;
    }

    expect(thrown?.response?.statusCode, 401);
    expect(thrown?.requestOptions.path, 'customer/wallet');
    expect(tokenStore.refreshToken, 'rejected-refresh');
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  final methods = <String>[];
  final paths = <String>[];
  final authorizationHeaders = <String?>[];
  final idempotencyHeaders = <String?>[];
  final requestIds = <String?>[];
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    methods.add(options.method);
    paths.add(options.path.replaceFirst(RegExp(r'^/+'), ''));
    authorizationHeaders.add(options.headers['Authorization']?.toString());
    idempotencyHeaders.add(options.headers['Idempotency-Key']?.toString());
    requestIds.add(options.headers['X-Request-Id']?.toString());
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    bodies.add(utf8.decode(bytes));
    return _json(200, const {'ok': true});
  }

  @override
  void close({bool force = false}) {}
}

class _RefreshingAuthAdapter implements HttpClientAdapter {
  _RefreshingAuthAdapter({this.omitRefreshToken = false});

  final bool omitRefreshToken;
  final paths = <String>[];
  final authorizationHeaders = <String?>[];
  final requestIds = <String?>[];
  int _pinAttempts = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path.replaceFirst(RegExp(r'^/+'), '');
    paths.add(path);
    authorizationHeaders.add(options.headers['Authorization']?.toString());
    requestIds.add(options.headers['X-Request-Id']?.toString());

    if (path == 'customer/auth/pin/verify') {
      _pinAttempts += 1;
      if (_pinAttempts == 1) {
        return _json(
          401,
          const {
            'code': 'authentication_required',
            'message':
                'Authentication token is missing, invalid, expired, or revoked.',
          },
        );
      }
      return _json(200, const {'ok': true});
    }

    if (path == 'customer/auth/refresh') {
      return _json(
        200,
        {
          'resource': {
            'token': 'fresh-access',
            if (!omitRefreshToken) 'refresh_token': 'fresh-refresh',
            'user': const {'id': 'cus_1'},
          },
        },
      );
    }

    return _json(404, {'message': 'Unexpected path $path'});
  }

  @override
  void close({bool force = false}) {}
}

class _RefreshFailureAdapter implements HttpClientAdapter {
  _RefreshFailureAdapter({
    required this.refreshStatus,
    required this.refreshBody,
  });

  final int refreshStatus;
  final Map<String, dynamic> refreshBody;
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path.replaceFirst(RegExp(r'^/+'), '');
    paths.add(path);

    if (path == 'customer/auth/refresh') {
      return _json(refreshStatus, refreshBody);
    }

    return _json(
      401,
      const {
        'error': {
          'code': 'authentication_required',
          'message':
              'Authentication token is missing, invalid, expired, or revoked.',
        },
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _MemoryTokenStore extends AuthTokenStore {
  String? _accessToken;
  String? _refreshToken;
  String? _customerId;

  @override
  String? get accessToken => _accessToken;

  @override
  String? get refreshToken => _refreshToken;

  @override
  String? get customerId => _customerId;

  @override
  bool get hasAccessToken => _accessToken != null && _accessToken!.isNotEmpty;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? customerId,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _customerId = customerId;
  }

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _customerId = null;
  }
}
